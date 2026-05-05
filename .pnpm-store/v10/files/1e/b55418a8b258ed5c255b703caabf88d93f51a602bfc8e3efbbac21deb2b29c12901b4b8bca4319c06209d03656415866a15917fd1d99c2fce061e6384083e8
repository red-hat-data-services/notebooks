import { BaseAPIRequestFactory } from './baseapi.js';
import { Configuration } from '../configuration.js';
import { RequestContext, ResponseContext, HttpInfo } from '../http/http.js';
/**
 * no description
 */
export declare class LogsApiRequestFactory extends BaseAPIRequestFactory {
    /**
     * @param logpath path to the log
     */
    logFileHandler(logpath: string, _options?: Configuration): Promise<RequestContext>;
    /**
     */
    logFileListHandler(_options?: Configuration): Promise<RequestContext>;
}
export declare class LogsApiResponseProcessor {
    /**
     * Unwraps the actual response sent by the server from the response context and deserializes the response content
     * to the expected objects
     *
     * @params response Response returned by the server for a request to logFileHandler
     * @throws ApiException if the response code was not in [200, 299]
     */
    logFileHandlerWithHttpInfo(response: ResponseContext): Promise<HttpInfo<void>>;
    /**
     * Unwraps the actual response sent by the server from the response context and deserializes the response content
     * to the expected objects
     *
     * @params response Response returned by the server for a request to logFileListHandler
     * @throws ApiException if the response code was not in [200, 299]
     */
    logFileListHandlerWithHttpInfo(response: ResponseContext): Promise<HttpInfo<void>>;
}
