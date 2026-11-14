import axios from "axios";
import { loadConfig } from "../src/config";

const config = loadConfig();

/** Base URL of the local server; the API tests expect it to be running already (see README). */
export const baseUrl = `http://${config.host}:${config.port}`;

/** The environment may export HTTP_PROXY for the browser; the local server must be reached directly. */
export const client = axios.create({ proxy: false });
