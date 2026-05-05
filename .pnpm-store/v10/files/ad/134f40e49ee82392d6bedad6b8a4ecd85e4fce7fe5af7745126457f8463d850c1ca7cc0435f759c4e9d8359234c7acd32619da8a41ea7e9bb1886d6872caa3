// TODO: better import syntax?
import { BaseAPIRequestFactory } from './baseapi.js';
import { HttpMethod, HttpInfo } from '../http/http.js';
import { ObjectSerializer } from '../models/ObjectSerializer.js';
import { ApiException } from './exception.js';
import { isCodeInRange } from '../util.js';
/**
 * no description
 */
export class NetworkingApiRequestFactory extends BaseAPIRequestFactory {
    /**
     * get information of a group
     */
    async getAPIGroup(_options) {
        var _a;
        let _config = _options || this.configuration;
        // Path Params
        const localVarPath = '/apis/networking.k8s.io/';
        // Make Request Context
        const requestContext = _config.baseServer.makeRequestContext(localVarPath, HttpMethod.GET);
        requestContext.setHeaderParam("Accept", "application/json, */*;q=0.8");
        let authMethod;
        // Apply auth methods
        authMethod = _config.authMethods["BearerToken"];
        if (authMethod === null || authMethod === void 0 ? void 0 : authMethod.applySecurityAuthentication) {
            await (authMethod === null || authMethod === void 0 ? void 0 : authMethod.applySecurityAuthentication(requestContext));
        }
        const defaultAuth = (_a = _config === null || _config === void 0 ? void 0 : _config.authMethods) === null || _a === void 0 ? void 0 : _a.default;
        if (defaultAuth === null || defaultAuth === void 0 ? void 0 : defaultAuth.applySecurityAuthentication) {
            await (defaultAuth === null || defaultAuth === void 0 ? void 0 : defaultAuth.applySecurityAuthentication(requestContext));
        }
        return requestContext;
    }
}
export class NetworkingApiResponseProcessor {
    /**
     * Unwraps the actual response sent by the server from the response context and deserializes the response content
     * to the expected objects
     *
     * @params response Response returned by the server for a request to getAPIGroup
     * @throws ApiException if the response code was not in [200, 299]
     */
    async getAPIGroupWithHttpInfo(response) {
        const contentType = ObjectSerializer.normalizeMediaType(response.headers["content-type"]);
        if (isCodeInRange("200", response.httpStatusCode)) {
            const body = ObjectSerializer.deserialize(ObjectSerializer.parse(await response.body.text(), contentType), "V1APIGroup", "");
            return new HttpInfo(response.httpStatusCode, response.headers, response.body, body);
        }
        if (isCodeInRange("401", response.httpStatusCode)) {
            throw new ApiException(response.httpStatusCode, "Unauthorized", undefined, response.headers);
        }
        // Work around for missing responses in specification, e.g. for petstore.yaml
        if (response.httpStatusCode >= 200 && response.httpStatusCode <= 299) {
            const body = ObjectSerializer.deserialize(ObjectSerializer.parse(await response.body.text(), contentType), "V1APIGroup", "");
            return new HttpInfo(response.httpStatusCode, response.headers, response.body, body);
        }
        throw new ApiException(response.httpStatusCode, "Unknown API Status Code!", await response.getBodyAsAny(), response.headers);
    }
}
//# sourceMappingURL=NetworkingApi.js.map