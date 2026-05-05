import { BaseAPIRequestFactory } from './baseapi.js';
import { Configuration } from '../configuration.js';
import { RequestContext, ResponseContext, HttpInfo } from '../http/http.js';
/**
 * no description
 */
export declare class OpenidApiRequestFactory extends BaseAPIRequestFactory {
    /**
     * get service account issuer OpenID JSON Web Key Set (contains public token verification keys)
     */
    getServiceAccountIssuerOpenIDKeyset(_options?: Configuration): Promise<RequestContext>;
}
export declare class OpenidApiResponseProcessor {
    /**
     * Unwraps the actual response sent by the server from the response context and deserializes the response content
     * to the expected objects
     *
     * @params response Response returned by the server for a request to getServiceAccountIssuerOpenIDKeyset
     * @throws ApiException if the response code was not in [200, 299]
     */
    getServiceAccountIssuerOpenIDKeysetWithHttpInfo(response: ResponseContext): Promise<HttpInfo<string>>;
}
