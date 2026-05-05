import child_process from 'node:child_process';
export class ExecAuth {
    constructor() {
        this.tokenCache = {};
        this.execFn = child_process.spawn;
    }
    isAuthProvider(user) {
        if (!user) {
            return false;
        }
        if (user.exec) {
            return true;
        }
        if (!user.authProvider) {
            return false;
        }
        return (user.authProvider.name === 'exec' || !!(user.authProvider.config && user.authProvider.config.exec));
    }
    async applyAuthentication(user, opts) {
        const credential = await this.getCredential(user);
        if (!credential) {
            return;
        }
        if (credential.status.clientCertificateData) {
            opts.cert = credential.status.clientCertificateData;
        }
        if (credential.status.clientKeyData) {
            opts.key = credential.status.clientKeyData;
        }
        const token = this.getToken(credential);
        if (token) {
            if (!opts.headers) {
                opts.headers = {};
            }
            opts.headers['Authorization'] = `Bearer ${token}`;
        }
    }
    getToken(credential) {
        if (!credential) {
            return null;
        }
        if (credential.status.token) {
            return credential.status.token;
        }
        return null;
    }
    async getCredential(user) {
        // TODO: Add a unit test for token caching.
        const cachedToken = this.tokenCache[user.name];
        if (cachedToken) {
            const date = Date.parse(cachedToken.status.expirationTimestamp);
            if (date > Date.now()) {
                return cachedToken;
            }
            this.tokenCache[user.name] = null;
        }
        let exec = null;
        if (user.authProvider && user.authProvider.config) {
            exec = user.authProvider.config.exec;
        }
        if (user.exec) {
            exec = user.exec;
        }
        if (!exec) {
            return null;
        }
        if (!exec.command) {
            throw new Error('No command was specified for exec authProvider!');
        }
        let opts = {};
        if (exec.env) {
            const env = { ...process.env };
            exec.env.forEach((elt) => (env[elt.name] = elt.value));
            opts = { ...opts, env };
        }
        return new Promise((resolve, reject) => {
            let stdoutData = '';
            let stderrData = '';
            let savedError = undefined;
            const subprocess = this.execFn(exec.command, exec.args, opts);
            subprocess.stdout.setEncoding('utf8');
            subprocess.stderr.setEncoding('utf8');
            subprocess.stdout.on('data', (data) => {
                stdoutData += data;
            });
            subprocess.stderr.on('data', (data) => {
                stderrData += data;
            });
            subprocess.on('error', (error) => {
                savedError = error;
            });
            subprocess.on('close', (code) => {
                if (savedError) {
                    reject(savedError);
                    return;
                }
                if (code !== 0) {
                    reject(new Error(stderrData));
                    return;
                }
                try {
                    const obj = JSON.parse(stdoutData);
                    this.tokenCache[user.name] = obj;
                    resolve(obj);
                }
                catch (error) {
                    reject(error);
                }
            });
        });
    }
}
//# sourceMappingURL=exec_auth.js.map