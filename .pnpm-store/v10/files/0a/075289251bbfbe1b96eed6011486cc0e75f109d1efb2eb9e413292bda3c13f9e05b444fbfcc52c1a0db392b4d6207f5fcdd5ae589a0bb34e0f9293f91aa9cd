import https from 'node:https';
import { Authenticator } from './auth.js';
import { User } from './config_types.js';
export declare class AzureAuth implements Authenticator {
    isAuthProvider(user: User): boolean;
    applyAuthentication(user: User, opts: https.RequestOptions): Promise<void>;
    private getToken;
    private isExpired;
    private updateAccessToken;
}
