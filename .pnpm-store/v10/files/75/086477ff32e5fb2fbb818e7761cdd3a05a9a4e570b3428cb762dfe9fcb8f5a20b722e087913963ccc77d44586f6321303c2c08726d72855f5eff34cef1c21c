import fs from 'node:fs';
export const ActionOnInvalid = {
    THROW: 'throw',
    FILTER: 'filter',
};
function defaultNewConfigOptions() {
    return {
        onInvalidEntry: ActionOnInvalid.THROW,
    };
}
export function newClusters(a, opts) {
    if (!Array.isArray(a)) {
        return [];
    }
    const options = Object.assign(defaultNewConfigOptions(), opts || {});
    return a.map(clusterIterator(options.onInvalidEntry)).filter(Boolean);
}
export function exportCluster(cluster) {
    return {
        name: cluster.name,
        cluster: {
            server: cluster.server,
            'certificate-authority-data': cluster.caData,
            'certificate-authority': cluster.caFile,
            'insecure-skip-tls-verify': cluster.skipTLSVerify,
            'tls-server-name': cluster.tlsServerName,
            'proxy-url': cluster.proxyUrl,
        },
    };
}
function clusterIterator(onInvalidEntry) {
    return (elt, i, list) => {
        try {
            if (!elt.name) {
                throw new Error(`clusters[${i}].name is missing`);
            }
            if (!elt.cluster) {
                throw new Error(`clusters[${i}].cluster is missing`);
            }
            if (!elt.cluster.server) {
                throw new Error(`clusters[${i}].cluster.server is missing`);
            }
            return {
                caData: elt.cluster['certificate-authority-data'],
                caFile: elt.cluster['certificate-authority'],
                name: elt.name,
                server: elt.cluster.server.replace(/\/$/, ''),
                skipTLSVerify: elt.cluster['insecure-skip-tls-verify'] === true,
                tlsServerName: elt.cluster['tls-server-name'],
                proxyUrl: elt.cluster['proxy-url'],
            };
        }
        catch (err) {
            switch (onInvalidEntry) {
                case ActionOnInvalid.FILTER:
                    return null;
                default:
                case ActionOnInvalid.THROW:
                    throw err;
            }
        }
    };
}
export function newUsers(a, opts) {
    if (!Array.isArray(a)) {
        return [];
    }
    const options = Object.assign(defaultNewConfigOptions(), opts || {});
    return a.map(userIterator(options.onInvalidEntry)).filter(Boolean);
}
export function exportUser(user) {
    return {
        name: user.name,
        user: {
            as: user.impersonateUser,
            'auth-provider': user.authProvider,
            'client-certificate-data': user.certData,
            'client-certificate': user.certFile,
            exec: user.exec,
            'client-key-data': user.keyData,
            'client-key': user.keyFile,
            token: user.token,
            password: user.password,
            username: user.username,
        },
    };
}
function userIterator(onInvalidEntry) {
    return (elt, i, list) => {
        try {
            if (!elt.name) {
                throw new Error(`users[${i}].name is missing`);
            }
            return {
                authProvider: elt.user ? elt.user['auth-provider'] : null,
                certData: elt.user ? elt.user['client-certificate-data'] : null,
                certFile: elt.user ? elt.user['client-certificate'] : null,
                exec: elt.user ? elt.user.exec : null,
                keyData: elt.user ? elt.user['client-key-data'] : null,
                keyFile: elt.user ? elt.user['client-key'] : null,
                name: elt.name,
                token: findToken(elt.user),
                password: elt.user ? elt.user.password : null,
                username: elt.user ? elt.user.username : null,
                impersonateUser: elt.user ? elt.user.as : null,
            };
        }
        catch (err) {
            switch (onInvalidEntry) {
                case ActionOnInvalid.FILTER:
                    return null;
                default:
                case ActionOnInvalid.THROW:
                    throw err;
            }
        }
    };
}
function findToken(user) {
    if (user) {
        if (user.token) {
            return user.token;
        }
        if (user['token-file']) {
            return fs.readFileSync(user['token-file']).toString();
        }
    }
}
export function newContexts(a, opts) {
    if (!Array.isArray(a)) {
        return [];
    }
    const options = Object.assign(defaultNewConfigOptions(), opts || {});
    return a.map(contextIterator(options.onInvalidEntry)).filter(Boolean);
}
export function exportContext(ctx) {
    return {
        name: ctx.name,
        context: ctx,
    };
}
function contextIterator(onInvalidEntry) {
    return (elt, i, list) => {
        try {
            if (!elt.name) {
                throw new Error(`contexts[${i}].name is missing`);
            }
            if (!elt.context) {
                throw new Error(`contexts[${i}].context is missing`);
            }
            if (!elt.context.cluster) {
                throw new Error(`contexts[${i}].context.cluster is missing`);
            }
            return {
                cluster: elt.context.cluster,
                name: elt.name,
                user: elt.context.user || undefined,
                namespace: elt.context.namespace || undefined,
            };
        }
        catch (err) {
            switch (onInvalidEntry) {
                case ActionOnInvalid.FILTER:
                    return null;
                default:
                case ActionOnInvalid.THROW:
                    throw err;
            }
        }
    };
}
//# sourceMappingURL=config_types.js.map