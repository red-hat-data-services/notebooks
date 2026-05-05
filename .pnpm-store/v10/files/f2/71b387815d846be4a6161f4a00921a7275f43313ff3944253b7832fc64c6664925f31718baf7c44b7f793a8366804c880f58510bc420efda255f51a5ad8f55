/**
 * Applies apiKey authentication to the request context.
 */
export class BearerTokenAuthentication {
    /**
     * Configures this api key authentication with the necessary properties
     *
     * @param apiKey: The api key to be used for every request
     */
    constructor(apiKey) {
        this.apiKey = apiKey;
    }
    getName() {
        return "BearerToken";
    }
    applySecurityAuthentication(context) {
        context.setHeaderParam("authorization", this.apiKey);
    }
}
/**
 * Creates the authentication methods from a swagger description.
 *
 */
export function configureAuthMethods(config) {
    let authMethods = {};
    if (!config) {
        return authMethods;
    }
    authMethods["default"] = config["default"];
    if (config["BearerToken"]) {
        authMethods["BearerToken"] = new BearerTokenAuthentication(config["BearerToken"]);
    }
    return authMethods;
}
//# sourceMappingURL=auth.js.map