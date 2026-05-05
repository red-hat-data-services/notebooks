import * as oidc from 'openid-client';
import { base64url } from 'rfc4648';
class OidcClient {
    constructor(c) {
        this.config = c;
    }
    async refresh(token) {
        const newToken = await oidc.refreshTokenGrant(this.config, token);
        return {
            id_token: newToken.id_token,
            refresh_token: newToken.refresh_token,
            expires_at: newToken.expiresIn(),
        };
    }
}
export class OpenIDConnectAuth {
    constructor() {
        // public for testing purposes.
        this.currentTokenExpiration = 0;
    }
    static decodeJWT(token) {
        const parts = token.split('.');
        if (parts.length !== 3) {
            return null;
        }
        const header = JSON.parse(new TextDecoder().decode(base64url.parse(parts[0], { loose: true })));
        const payload = JSON.parse(new TextDecoder().decode(base64url.parse(parts[1], { loose: true })));
        const signature = parts[2];
        return {
            header,
            payload,
            signature,
        };
    }
    static expirationFromToken(token) {
        const jwt = OpenIDConnectAuth.decodeJWT(token);
        if (!jwt) {
            return 0;
        }
        return jwt.payload.exp;
    }
    isAuthProvider(user) {
        if (!user.authProvider) {
            return false;
        }
        return user.authProvider.name === 'oidc';
    }
    /**
     * Setup the authentication header for oidc authed clients
     * @param user user info
     * @param opts request options
     * @param overrideClient for testing, a preconfigured oidc client
     */
    async applyAuthentication(user, opts, overrideClient) {
        const token = await this.getToken(user, overrideClient);
        if (token) {
            opts.headers['Authorization'] = `Bearer ${token}`;
        }
    }
    async getToken(user, overrideClient) {
        if (!user.authProvider.config) {
            return null;
        }
        if (!user.authProvider.config['client-secret']) {
            user.authProvider.config['client-secret'] = '';
        }
        if (!user.authProvider.config || !user.authProvider.config['id-token']) {
            return null;
        }
        return this.refresh(user, overrideClient);
    }
    async refresh(user, overrideClient) {
        if (this.currentTokenExpiration === 0) {
            this.currentTokenExpiration = OpenIDConnectAuth.expirationFromToken(user.authProvider.config['id-token']);
        }
        if (Date.now() / 1000 > this.currentTokenExpiration) {
            if (!user.authProvider.config['client-id'] ||
                !user.authProvider.config['refresh-token'] ||
                !user.authProvider.config['idp-issuer-url']) {
                return null;
            }
            const client = overrideClient ? overrideClient : await this.getClient(user);
            const newToken = await client.refresh(user.authProvider.config['refresh-token']);
            user.authProvider.config['id-token'] = newToken.id_token;
            user.authProvider.config['refresh-token'] = newToken.refresh_token;
            this.currentTokenExpiration = newToken.expires_at;
        }
        return user.authProvider.config['id-token'];
    }
    async getClient(user) {
        const configuration = await oidc.discovery(user.authProvider.config['idp-issuer-url'], user.authProvider.config['client-id']);
        return new OidcClient(configuration);
    }
}
//# sourceMappingURL=oidc_auth.js.map