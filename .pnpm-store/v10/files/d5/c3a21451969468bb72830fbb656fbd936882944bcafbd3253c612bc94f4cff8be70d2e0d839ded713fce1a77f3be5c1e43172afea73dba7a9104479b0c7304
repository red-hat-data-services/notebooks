import https from 'node:https';
import { Authenticator } from './auth.js';
import { User } from './config_types.js';
export declare class FileAuth implements Authenticator {
    private token;
    private lastRead;
    isAuthProvider(user: User): boolean;
    applyAuthentication(user: User, opts: https.RequestOptions): Promise<void>;
    private refreshToken;
    private isTokenExpired;
}
