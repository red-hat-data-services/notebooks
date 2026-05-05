// TODO: better import syntax?
import { BaseAPIRequestFactory, RequiredError } from './baseapi.js';
import { HttpMethod, HttpInfo } from '../http/http.js';
import { ObjectSerializer } from '../models/ObjectSerializer.js';
import { ApiException } from './exception.js';
import { isCodeInRange } from '../util.js';
/**
 * no description
 */
export class AuthenticationV1ApiRequestFactory extends BaseAPIRequestFactory {
    /**
     * create a SelfSubjectReview
     * @param body
     * @param dryRun When present, indicates that modifications should not be persisted. An invalid or unrecognized dryRun directive will result in an error response and no further processing of the request. Valid values are: - All: all dry run stages will be processed
     * @param fieldManager fieldManager is a name associated with the actor or entity that is making these changes. The value must be less than or 128 characters long, and only contain printable characters, as defined by https://golang.org/pkg/unicode/#IsPrint.
     * @param fieldValidation fieldValidation instructs the server on how to handle objects in the request (POST/PUT/PATCH) containing unknown or duplicate fields. Valid values are: - Ignore: This will ignore any unknown fields that are silently dropped from the object, and will ignore all but the last duplicate field that the decoder encounters. This is the default behavior prior to v1.23. - Warn: This will send a warning via the standard warning response header for each unknown field that is dropped from the object, and for each duplicate field that is encountered. The request will still succeed if there are no other errors, and will only persist the last of any duplicate fields. This is the default in v1.23+ - Strict: This will fail the request with a BadRequest error if any unknown fields would be dropped from the object, or if any duplicate fields are present. The error returned from the server will contain all unknown and duplicate fields encountered.
     * @param pretty If \&#39;true\&#39;, then the output is pretty printed. Defaults to \&#39;false\&#39; unless the user-agent indicates a browser or command-line HTTP tool (curl and wget).
     */
    async createSelfSubjectReview(body, dryRun, fieldManager, fieldValidation, pretty, _options) {
        var _a;
        let _config = _options || this.configuration;
        // verify required parameter 'body' is not null or undefined
        if (body === null || body === undefined) {
            throw new RequiredError("AuthenticationV1Api", "createSelfSubjectReview", "body");
        }
        // Path Params
        const localVarPath = '/apis/authentication.k8s.io/v1/selfsubjectreviews';
        // Make Request Context
        const requestContext = _config.baseServer.makeRequestContext(localVarPath, HttpMethod.POST);
        requestContext.setHeaderParam("Accept", "application/json, */*;q=0.8");
        // Query Params
        if (dryRun !== undefined) {
            requestContext.setQueryParam("dryRun", ObjectSerializer.serialize(dryRun, "string", ""));
        }
        // Query Params
        if (fieldManager !== undefined) {
            requestContext.setQueryParam("fieldManager", ObjectSerializer.serialize(fieldManager, "string", ""));
        }
        // Query Params
        if (fieldValidation !== undefined) {
            requestContext.setQueryParam("fieldValidation", ObjectSerializer.serialize(fieldValidation, "string", ""));
        }
        // Query Params
        if (pretty !== undefined) {
            requestContext.setQueryParam("pretty", ObjectSerializer.serialize(pretty, "string", ""));
        }
        // Body Params
        const contentType = ObjectSerializer.getPreferredMediaType([]);
        requestContext.setHeaderParam("Content-Type", contentType);
        const serializedBody = ObjectSerializer.stringify(ObjectSerializer.serialize(body, "V1SelfSubjectReview", ""), contentType);
        requestContext.setBody(serializedBody);
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
    /**
     * create a TokenReview
     * @param body
     * @param dryRun When present, indicates that modifications should not be persisted. An invalid or unrecognized dryRun directive will result in an error response and no further processing of the request. Valid values are: - All: all dry run stages will be processed
     * @param fieldManager fieldManager is a name associated with the actor or entity that is making these changes. The value must be less than or 128 characters long, and only contain printable characters, as defined by https://golang.org/pkg/unicode/#IsPrint.
     * @param fieldValidation fieldValidation instructs the server on how to handle objects in the request (POST/PUT/PATCH) containing unknown or duplicate fields. Valid values are: - Ignore: This will ignore any unknown fields that are silently dropped from the object, and will ignore all but the last duplicate field that the decoder encounters. This is the default behavior prior to v1.23. - Warn: This will send a warning via the standard warning response header for each unknown field that is dropped from the object, and for each duplicate field that is encountered. The request will still succeed if there are no other errors, and will only persist the last of any duplicate fields. This is the default in v1.23+ - Strict: This will fail the request with a BadRequest error if any unknown fields would be dropped from the object, or if any duplicate fields are present. The error returned from the server will contain all unknown and duplicate fields encountered.
     * @param pretty If \&#39;true\&#39;, then the output is pretty printed. Defaults to \&#39;false\&#39; unless the user-agent indicates a browser or command-line HTTP tool (curl and wget).
     */
    async createTokenReview(body, dryRun, fieldManager, fieldValidation, pretty, _options) {
        var _a;
        let _config = _options || this.configuration;
        // verify required parameter 'body' is not null or undefined
        if (body === null || body === undefined) {
            throw new RequiredError("AuthenticationV1Api", "createTokenReview", "body");
        }
        // Path Params
        const localVarPath = '/apis/authentication.k8s.io/v1/tokenreviews';
        // Make Request Context
        const requestContext = _config.baseServer.makeRequestContext(localVarPath, HttpMethod.POST);
        requestContext.setHeaderParam("Accept", "application/json, */*;q=0.8");
        // Query Params
        if (dryRun !== undefined) {
            requestContext.setQueryParam("dryRun", ObjectSerializer.serialize(dryRun, "string", ""));
        }
        // Query Params
        if (fieldManager !== undefined) {
            requestContext.setQueryParam("fieldManager", ObjectSerializer.serialize(fieldManager, "string", ""));
        }
        // Query Params
        if (fieldValidation !== undefined) {
            requestContext.setQueryParam("fieldValidation", ObjectSerializer.serialize(fieldValidation, "string", ""));
        }
        // Query Params
        if (pretty !== undefined) {
            requestContext.setQueryParam("pretty", ObjectSerializer.serialize(pretty, "string", ""));
        }
        // Body Params
        const contentType = ObjectSerializer.getPreferredMediaType([]);
        requestContext.setHeaderParam("Content-Type", contentType);
        const serializedBody = ObjectSerializer.stringify(ObjectSerializer.serialize(body, "V1TokenReview", ""), contentType);
        requestContext.setBody(serializedBody);
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
    /**
     * get available resources
     */
    async getAPIResources(_options) {
        var _a;
        let _config = _options || this.configuration;
        // Path Params
        const localVarPath = '/apis/authentication.k8s.io/v1/';
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
export class AuthenticationV1ApiResponseProcessor {
    /**
     * Unwraps the actual response sent by the server from the response context and deserializes the response content
     * to the expected objects
     *
     * @params response Response returned by the server for a request to createSelfSubjectReview
     * @throws ApiException if the response code was not in [200, 299]
     */
    async createSelfSubjectReviewWithHttpInfo(response) {
        const contentType = ObjectSerializer.normalizeMediaType(response.headers["content-type"]);
        if (isCodeInRange("200", response.httpStatusCode)) {
            const body = ObjectSerializer.deserialize(ObjectSerializer.parse(await response.body.text(), contentType), "V1SelfSubjectReview", "");
            return new HttpInfo(response.httpStatusCode, response.headers, response.body, body);
        }
        if (isCodeInRange("201", response.httpStatusCode)) {
            const body = ObjectSerializer.deserialize(ObjectSerializer.parse(await response.body.text(), contentType), "V1SelfSubjectReview", "");
            return new HttpInfo(response.httpStatusCode, response.headers, response.body, body);
        }
        if (isCodeInRange("202", response.httpStatusCode)) {
            const body = ObjectSerializer.deserialize(ObjectSerializer.parse(await response.body.text(), contentType), "V1SelfSubjectReview", "");
            return new HttpInfo(response.httpStatusCode, response.headers, response.body, body);
        }
        if (isCodeInRange("401", response.httpStatusCode)) {
            throw new ApiException(response.httpStatusCode, "Unauthorized", undefined, response.headers);
        }
        // Work around for missing responses in specification, e.g. for petstore.yaml
        if (response.httpStatusCode >= 200 && response.httpStatusCode <= 299) {
            const body = ObjectSerializer.deserialize(ObjectSerializer.parse(await response.body.text(), contentType), "V1SelfSubjectReview", "");
            return new HttpInfo(response.httpStatusCode, response.headers, response.body, body);
        }
        throw new ApiException(response.httpStatusCode, "Unknown API Status Code!", await response.getBodyAsAny(), response.headers);
    }
    /**
     * Unwraps the actual response sent by the server from the response context and deserializes the response content
     * to the expected objects
     *
     * @params response Response returned by the server for a request to createTokenReview
     * @throws ApiException if the response code was not in [200, 299]
     */
    async createTokenReviewWithHttpInfo(response) {
        const contentType = ObjectSerializer.normalizeMediaType(response.headers["content-type"]);
        if (isCodeInRange("200", response.httpStatusCode)) {
            const body = ObjectSerializer.deserialize(ObjectSerializer.parse(await response.body.text(), contentType), "V1TokenReview", "");
            return new HttpInfo(response.httpStatusCode, response.headers, response.body, body);
        }
        if (isCodeInRange("201", response.httpStatusCode)) {
            const body = ObjectSerializer.deserialize(ObjectSerializer.parse(await response.body.text(), contentType), "V1TokenReview", "");
            return new HttpInfo(response.httpStatusCode, response.headers, response.body, body);
        }
        if (isCodeInRange("202", response.httpStatusCode)) {
            const body = ObjectSerializer.deserialize(ObjectSerializer.parse(await response.body.text(), contentType), "V1TokenReview", "");
            return new HttpInfo(response.httpStatusCode, response.headers, response.body, body);
        }
        if (isCodeInRange("401", response.httpStatusCode)) {
            throw new ApiException(response.httpStatusCode, "Unauthorized", undefined, response.headers);
        }
        // Work around for missing responses in specification, e.g. for petstore.yaml
        if (response.httpStatusCode >= 200 && response.httpStatusCode <= 299) {
            const body = ObjectSerializer.deserialize(ObjectSerializer.parse(await response.body.text(), contentType), "V1TokenReview", "");
            return new HttpInfo(response.httpStatusCode, response.headers, response.body, body);
        }
        throw new ApiException(response.httpStatusCode, "Unknown API Status Code!", await response.getBodyAsAny(), response.headers);
    }
    /**
     * Unwraps the actual response sent by the server from the response context and deserializes the response content
     * to the expected objects
     *
     * @params response Response returned by the server for a request to getAPIResources
     * @throws ApiException if the response code was not in [200, 299]
     */
    async getAPIResourcesWithHttpInfo(response) {
        const contentType = ObjectSerializer.normalizeMediaType(response.headers["content-type"]);
        if (isCodeInRange("200", response.httpStatusCode)) {
            const body = ObjectSerializer.deserialize(ObjectSerializer.parse(await response.body.text(), contentType), "V1APIResourceList", "");
            return new HttpInfo(response.httpStatusCode, response.headers, response.body, body);
        }
        if (isCodeInRange("401", response.httpStatusCode)) {
            throw new ApiException(response.httpStatusCode, "Unauthorized", undefined, response.headers);
        }
        // Work around for missing responses in specification, e.g. for petstore.yaml
        if (response.httpStatusCode >= 200 && response.httpStatusCode <= 299) {
            const body = ObjectSerializer.deserialize(ObjectSerializer.parse(await response.body.text(), contentType), "V1APIResourceList", "");
            return new HttpInfo(response.httpStatusCode, response.headers, response.body, body);
        }
        throw new ApiException(response.httpStatusCode, "Unknown API Status Code!", await response.getBodyAsAny(), response.headers);
    }
}
//# sourceMappingURL=AuthenticationV1Api.js.map