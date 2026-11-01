#include "native_os.h"

#include <godot_cpp/classes/display_server.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/memory.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#ifdef _WIN32
#include <UIAutomation.h>
#include <dwmapi.h>
#include <objbase.h>
#include <windows.h>
#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif
#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE_BEFORE_20H1
#define DWMWA_USE_IMMERSIVE_DARK_MODE_BEFORE_20H1 19
#endif
#endif

using namespace godot;

NativeOS *NativeOS::singleton = nullptr;

namespace {
#ifdef _WIN32
HWND window_handle_from_id(int window_id) {
	DisplayServer *display = DisplayServer::get_singleton();
	if (display == nullptr) {
		return nullptr;
	}
	const int64_t handle = display->window_get_native_handle(DisplayServer::WINDOW_HANDLE, window_id);
	HWND hwnd = reinterpret_cast<HWND>(static_cast<uintptr_t>(handle));
	if (hwnd == nullptr || !IsWindow(hwnd)) {
		return nullptr;
	}
	return hwnd;
}

struct TitleBarThemeApi {
	static constexpr int k_app_mode_allow_dark = 1;
	static constexpr int k_app_mode_force_light = 3;

	DWORD build = 0;
	int(WINAPI * set_app_mode)(int) = nullptr;
	void(WINAPI * refresh_policy)() = nullptr;
	void(WINAPI * flush_menu)() = nullptr;
	bool(WINAPI * allow_dark_window)(HWND, bool) = nullptr;

	static TitleBarThemeApi &get() {
		static TitleBarThemeApi api;
		static bool ready = false;
		if (ready) {
			return api;
		}
		ready = true;
		HMODULE ntdll = GetModuleHandleW(L"ntdll.dll");
		if (ntdll != nullptr) {
			using RtlGetVersionFn = LONG(WINAPI *)(OSVERSIONINFOEXW *);
			const RtlGetVersionFn rtl_get_version = reinterpret_cast<RtlGetVersionFn>(GetProcAddress(ntdll, "RtlGetVersion"));
			OSVERSIONINFOEXW version = {};
			version.dwOSVersionInfoSize = sizeof(version);
			if (rtl_get_version != nullptr && rtl_get_version(&version) == 0) {
				api.build = version.dwBuildNumber;
			}
		}
		HMODULE ux_theme = LoadLibraryW(L"uxtheme.dll");
		if (ux_theme != nullptr) {
			api.set_app_mode = reinterpret_cast<int(WINAPI *)(int)>(GetProcAddress(ux_theme, MAKEINTRESOURCEA(135)));
			api.refresh_policy = reinterpret_cast<void(WINAPI *)()>(GetProcAddress(ux_theme, MAKEINTRESOURCEA(104)));
			api.flush_menu = reinterpret_cast<void(WINAPI *)()>(GetProcAddress(ux_theme, MAKEINTRESOURCEA(136)));
			api.allow_dark_window = reinterpret_cast<bool(WINAPI *)(HWND, bool)>(GetProcAddress(ux_theme, MAKEINTRESOURCEA(133)));
		}
		return api;
	}
};

Vector2i win32_point_to_godot_screen(POINT pt) {
	POINT mouse_pt = {};
	GetCursorPos(&mouse_pt);
	const Vector2i godot_mouse = DisplayServer::get_singleton()->mouse_get_position();
	return godot_mouse + Vector2i(pt.x - mouse_pt.x, pt.y - mouse_pt.y);
}

bool try_win32_gui_caret(Vector2i &r_pos) {
	HWND foreground = GetForegroundWindow();
	if (foreground == nullptr) {
		return false;
	}
	DWORD thread_id = GetWindowThreadProcessId(foreground, nullptr);
	if (thread_id == 0) {
		return false;
	}
	GUITHREADINFO info = {};
	info.cbSize = sizeof(info);
	if (!GetGUIThreadInfo(thread_id, &info) || info.hwndCaret == nullptr) {
		return false;
	}
	const RECT &rc = info.rcCaret;
	POINT caret_pt = {};
	caret_pt.x = rc.left;
	caret_pt.y = rc.top == rc.bottom ? rc.top : (rc.top + rc.bottom) / 2;
	if (!ClientToScreen(info.hwndCaret, &caret_pt)) {
		return false;
	}
	r_pos = win32_point_to_godot_screen(caret_pt);
	return true;
}

bool uia_first_rect_anchor(IUIAutomationTextRange *range, POINT &r_pt) {
	if (range == nullptr) {
		return false;
	}
	SAFEARRAY *rects = nullptr;
	if (FAILED(range->GetBoundingRectangles(&rects)) || rects == nullptr) {
		return false;
	}
	LONG lower = 0;
	LONG upper = -1;
	SafeArrayGetLBound(rects, 1, &lower);
	SafeArrayGetUBound(rects, 1, &upper);
	const LONG count = upper - lower + 1;
	if (count < 4) {
		SafeArrayDestroy(rects);
		return false;
	}
	double left = 0.0;
	double top = 0.0;
	double width = 0.0;
	double height = 0.0;
	LONG idx = lower;
	SafeArrayGetElement(rects, &idx, &left);
	idx += 1;
	SafeArrayGetElement(rects, &idx, &top);
	idx += 1;
	SafeArrayGetElement(rects, &idx, &width);
	idx += 1;
	SafeArrayGetElement(rects, &idx, &height);
	SafeArrayDestroy(rects);
	// Caret ranges are often a thin vertical strip — pin to the left edge, mid height.
	r_pt.x = static_cast<LONG>(left);
	r_pt.y = static_cast<LONG>(top + (height > 0.0 ? height * 0.5 : 0.0));
	return true;
}

bool try_uia_caret(Vector2i &r_pos) {
	const HRESULT init_hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
	if (FAILED(init_hr) && init_hr != RPC_E_CHANGED_MODE) {
		return false;
	}

	IUIAutomation *automation = nullptr;
	HRESULT hr = CoCreateInstance(CLSID_CUIAutomation, nullptr, CLSCTX_INPROC_SERVER, IID_IUIAutomation, reinterpret_cast<void **>(&automation));
	if (FAILED(hr) || automation == nullptr) {
		return false;
	}

	IUIAutomationElement *focused = nullptr;
	hr = automation->GetFocusedElement(&focused);
	if (FAILED(hr) || focused == nullptr) {
		automation->Release();
		return false;
	}

	bool ok = false;
	POINT pt = {};

	IUIAutomationTextPattern2 *text2 = nullptr;
	hr = focused->GetCurrentPatternAs(UIA_TextPattern2Id, IID_IUIAutomationTextPattern2, reinterpret_cast<void **>(&text2));
	if (SUCCEEDED(hr) && text2 != nullptr) {
		BOOL is_active = FALSE;
		IUIAutomationTextRange *caret_range = nullptr;
		hr = text2->GetCaretRange(&is_active, &caret_range);
		if (SUCCEEDED(hr) && caret_range != nullptr) {
			ok = uia_first_rect_anchor(caret_range, pt);
			caret_range->Release();
		}
		text2->Release();
	}

	if (!ok) {
		IUIAutomationTextPattern *text = nullptr;
		hr = focused->GetCurrentPatternAs(UIA_TextPatternId, IID_IUIAutomationTextPattern, reinterpret_cast<void **>(&text));
		if (SUCCEEDED(hr) && text != nullptr) {
			IUIAutomationTextRangeArray *ranges = nullptr;
			hr = text->GetSelection(&ranges);
			if (SUCCEEDED(hr) && ranges != nullptr) {
				int length = 0;
				ranges->get_Length(&length);
				if (length > 0) {
					IUIAutomationTextRange *range = nullptr;
					if (SUCCEEDED(ranges->GetElement(0, &range)) && range != nullptr) {
						ok = uia_first_rect_anchor(range, pt);
						range->Release();
					}
				}
				ranges->Release();
			}
			text->Release();
		}
	}

	focused->Release();
	automation->Release();
	if (!ok) {
		return false;
	}
	r_pos = win32_point_to_godot_screen(pt);
	return true;
}
#endif
} // namespace

NativeOS *NativeOS::get_singleton() {
	return singleton;
}

void NativeOS::create_singleton() {
	if (singleton != nullptr) {
		return;
	}
	singleton = memnew(NativeOS);
	Engine::get_singleton()->register_singleton("NativeOS", singleton);
}

void NativeOS::destroy_singleton() {
	if (singleton == nullptr) {
		return;
	}
	Engine::get_singleton()->unregister_singleton("NativeOS");
	memdelete(singleton);
	singleton = nullptr;
}

void NativeOS::_bind_methods() {
	ClassDB::bind_method(D_METHOD("paste_clipboard"), &NativeOS::paste_clipboard);
	ClassDB::bind_method(D_METHOD("remember_foreground_window"), &NativeOS::remember_foreground_window);
	ClassDB::bind_method(D_METHOD("restore_foreground_window"), &NativeOS::restore_foreground_window);
	ClassDB::bind_method(D_METHOD("get_caret_screen_position"), &NativeOS::get_caret_screen_position);
	ClassDB::bind_method(D_METHOD("capture_screen", "path"), &NativeOS::capture_screen);
	ClassDB::bind_method(D_METHOD("apply_title_bar_dark_mode", "window_id", "dark_mode"), &NativeOS::apply_title_bar_dark_mode);
}

bool NativeOS::apply_title_bar_dark_mode(int window_id, bool dark_mode) {
#ifdef _WIN32
	HWND hwnd = window_handle_from_id(window_id);
	if (hwnd == nullptr) {
		return false;
	}
	TitleBarThemeApi &api = TitleBarThemeApi::get();
	if (api.build < 18363) {
		return false;
	}
	if (api.set_app_mode != nullptr) {
		api.set_app_mode(dark_mode ? TitleBarThemeApi::k_app_mode_allow_dark : TitleBarThemeApi::k_app_mode_force_light);
	}
	if (api.refresh_policy != nullptr) {
		api.refresh_policy();
	}
	if (api.flush_menu != nullptr) {
		api.flush_menu();
	}
	if (api.allow_dark_window != nullptr) {
		api.allow_dark_window(hwnd, dark_mode);
	}
	const BOOL dark = dark_mode ? TRUE : FALSE;
	const DWORD immersive_attr = api.build < 19041 ? DWMWA_USE_IMMERSIVE_DARK_MODE_BEFORE_20H1 : DWMWA_USE_IMMERSIVE_DARK_MODE;
	const bool applied = SUCCEEDED(DwmSetWindowAttribute(hwnd, immersive_attr, &dark, sizeof(dark)));
	SetWindowPos(hwnd, nullptr, 0, 0, 0, 0, SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
	SendMessageW(hwnd, WM_NCACTIVATE, FALSE, 0);
	SendMessageW(hwnd, WM_NCACTIVATE, TRUE, 0);
	DwmFlush();
	return applied;
#else
	(void)window_id;
	(void)dark_mode;
	return false;
#endif
}

void NativeOS::paste_clipboard() {
#ifdef _WIN32
	INPUT inputs[4] = {};
	inputs[0].type = INPUT_KEYBOARD;
	inputs[0].ki.wVk = VK_CONTROL;
	inputs[1].type = INPUT_KEYBOARD;
	inputs[1].ki.wVk = 'V';
	inputs[2].type = INPUT_KEYBOARD;
	inputs[2].ki.wVk = 'V';
	inputs[2].ki.dwFlags = KEYEVENTF_KEYUP;
	inputs[3].type = INPUT_KEYBOARD;
	inputs[3].ki.wVk = VK_CONTROL;
	inputs[3].ki.dwFlags = KEYEVENTF_KEYUP;
	const UINT sent = SendInput(4, inputs, sizeof(INPUT));
	if (sent != 4) {
		UtilityFunctions::printerr("NativeOS.paste_clipboard: SendInput failed");
	}
#else
	UtilityFunctions::printerr("NativeOS.paste_clipboard: only implemented on Windows");
#endif
}

bool NativeOS::remember_foreground_window() {
#ifdef _WIN32
	HWND foreground = GetForegroundWindow();
	if (foreground == nullptr || !IsWindow(foreground)) {
		remembered_foreground = nullptr;
		return false;
	}
	remembered_foreground = foreground;
	return true;
#else
	return false;
#endif
}

bool NativeOS::restore_foreground_window() {
#ifdef _WIN32
	HWND target = static_cast<HWND>(remembered_foreground);
	remembered_foreground = nullptr;
	if (target == nullptr || !IsWindow(target)) {
		return false;
	}
	// AttachThreadInput lets SetForegroundWindow succeed when this process currently owns focus
	// (e.g. after a Godot Window briefly stole activation for keyboard candidate picking).
	HWND current = GetForegroundWindow();
	const DWORD this_thread = GetCurrentThreadId();
	const DWORD current_thread = current != nullptr ? GetWindowThreadProcessId(current, nullptr) : 0;
	const DWORD target_thread = GetWindowThreadProcessId(target, nullptr);
	bool attached_current = false;
	bool attached_target = false;
	if (current != nullptr && current_thread != 0 && current_thread != this_thread) {
		attached_current = AttachThreadInput(this_thread, current_thread, TRUE) != 0;
	}
	if (target_thread != 0 && target_thread != this_thread && target_thread != current_thread) {
		attached_target = AttachThreadInput(this_thread, target_thread, TRUE) != 0;
	}
	BringWindowToTop(target);
	const BOOL ok = SetForegroundWindow(target);
	if (attached_target) {
		AttachThreadInput(this_thread, target_thread, FALSE);
	}
	if (attached_current) {
		AttachThreadInput(this_thread, current_thread, FALSE);
	}
	return ok != 0;
#else
	return false;
#endif
}

Variant NativeOS::get_caret_screen_position() const {
#ifdef _WIN32
	Vector2i pos;
	// Native Win32 carets (Notepad, Explorer, many desktop apps).
	if (try_win32_gui_caret(pos)) {
		return pos;
	}
	// Chrome / Edge / Electron / WPF / etc. often only expose caret via UI Automation.
	if (try_uia_caret(pos)) {
		return pos;
	}
	return Variant();
#else
	return Variant();
#endif
}

bool NativeOS::capture_screen(const String &path) const {
#ifdef _WIN32
	if (path.is_empty()) {
		UtilityFunctions::printerr("NativeOS.capture_screen: path is empty");
		return false;
	}

	POINT cursor = {};
	if (!GetCursorPos(&cursor)) {
		UtilityFunctions::printerr("NativeOS.capture_screen: GetCursorPos failed");
		return false;
	}

	HMONITOR monitor = MonitorFromPoint(cursor, MONITOR_DEFAULTTONEAREST);
	MONITORINFO info = {};
	info.cbSize = sizeof(info);
	if (!GetMonitorInfoW(monitor, &info)) {
		UtilityFunctions::printerr("NativeOS.capture_screen: GetMonitorInfo failed");
		return false;
	}

	const RECT &screen = info.rcMonitor;
	const int width = screen.right - screen.left;
	const int height = screen.bottom - screen.top;
	if (width <= 0 || height <= 0) {
		UtilityFunctions::printerr("NativeOS.capture_screen: invalid monitor size");
		return false;
	}

	HDC screen_dc = GetDC(nullptr);
	if (screen_dc == nullptr) {
		UtilityFunctions::printerr("NativeOS.capture_screen: GetDC failed");
		return false;
	}
	HDC mem_dc = CreateCompatibleDC(screen_dc);
	HBITMAP bitmap = CreateCompatibleBitmap(screen_dc, width, height);
	if (mem_dc == nullptr || bitmap == nullptr) {
		if (bitmap != nullptr) {
			DeleteObject(bitmap);
		}
		if (mem_dc != nullptr) {
			DeleteDC(mem_dc);
		}
		ReleaseDC(nullptr, screen_dc);
		UtilityFunctions::printerr("NativeOS.capture_screen: CreateCompatibleDC/Bitmap failed");
		return false;
	}

	HGDIOBJ old_obj = SelectObject(mem_dc, bitmap);
	const BOOL blitted = BitBlt(mem_dc, 0, 0, width, height, screen_dc, screen.left, screen.top, SRCCOPY | CAPTUREBLT);

	BITMAPINFOHEADER header = {};
	header.biSize = sizeof(header);
	header.biWidth = width;
	header.biHeight = -height; // top-down
	header.biPlanes = 1;
	header.biBitCount = 32;
	header.biCompression = BI_RGB;

	PackedByteArray pixels;
	pixels.resize(width * height * 4);
	const int got = blitted ? GetDIBits(mem_dc, bitmap, 0, height, pixels.ptrw(), reinterpret_cast<BITMAPINFO *>(&header), DIB_RGB_COLORS) : 0;

	SelectObject(mem_dc, old_obj);
	DeleteObject(bitmap);
	DeleteDC(mem_dc);
	ReleaseDC(nullptr, screen_dc);

	if (got == 0) {
		UtilityFunctions::printerr("NativeOS.capture_screen: BitBlt/GetDIBits failed");
		return false;
	}

	// GDI returns BGRA with alpha often 0 — convert to opaque RGBA for Image.
	uint8_t *bytes = pixels.ptrw();
	const int pixel_count = width * height;
	for (int i = 0; i < pixel_count; i++) {
		const int o = i * 4;
		const uint8_t b = bytes[o];
		const uint8_t r = bytes[o + 2];
		bytes[o] = r;
		bytes[o + 2] = b;
		bytes[o + 3] = 255;
	}

	const Ref<Image> image = Image::create_from_data(width, height, false, Image::FORMAT_RGBA8, pixels);
	if (image.is_null() || image->is_empty()) {
		UtilityFunctions::printerr("NativeOS.capture_screen: Image.create_from_data failed");
		return false;
	}
	const Error err = image->save_png(path);
	if (err != OK) {
		UtilityFunctions::printerr("NativeOS.capture_screen: save_png failed (", static_cast<int64_t>(err), ") path=[", path, "]");
		return false;
	}
	return true;
#else
	UtilityFunctions::printerr("NativeOS.capture_screen: only implemented on Windows");
	return false;
#endif
}
