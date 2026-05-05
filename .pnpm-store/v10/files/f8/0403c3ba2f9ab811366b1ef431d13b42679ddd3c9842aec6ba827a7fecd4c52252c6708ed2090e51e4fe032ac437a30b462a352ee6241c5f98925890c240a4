import { BaseAPIRequestFactory } from './baseapi.js';
import { Configuration } from '../configuration.js';
import { RequestContext, ResponseContext, HttpInfo } from '../http/http.js';
import { VersionInfo } from '../models/VersionInfo.js';
/**
 * no description
 */
export declare class VersionApiRequestFactory extends BaseAPIRequestFactory {
    /**
     * get the version information for this server
     */
    getCode(_options?: Configuration): Promise<RequestContext>;
}
export declare class VersionApiResponseProcessor {
    /**
     * Unwraps the actual response sent by the server from the response context and deserializes the response content
     * to the expected objects
     *
     * @params response Response returned by the server for a request to getCode
     * @throws ApiException if the response code was not in [200, 299]
     */
    getCodeWithHttpInfo(response: ResponseContext): Promise<HttpInfo<VersionInfo>>;
}
