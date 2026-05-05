export declare const ActionOnInvalid: {
    readonly THROW: "throw";
    readonly FILTER: "filter";
};
export type ActionOnInvalid = (typeof ActionOnInvalid)[keyof typeof ActionOnInvalid];
export interface ConfigOptions {
    onInvalidEntry: ActionOnInvalid;
}
export interface Cluster {
    readonly name: string;
    readonly caData?: string;
    caFile?: string;
    readonly server: string;
    readonly tlsServerName?: string;
    readonly skipTLSVerify: boolean;
    readonly proxyUrl?: string;
}
export declare function newClusters(a: any, opts?: Partial<ConfigOptions>): Cluster[];
export declare function exportCluster(cluster: Cluster): any;
export interface User {
    readonly name: string;
    readonly certData?: string;
    certFile?: string;
    readonly exec?: any;
    readonly keyData?: string;
    keyFile?: string;
    readonly authProvider?: any;
    readonly token?: string;
    readonly username?: string;
    readonly password?: string;
    readonly impersonateUser?: string;
}
export declare function newUsers(a: any, opts?: Partial<ConfigOptions>): User[];
export declare function exportUser(user: User): any;
export interface Context {
    readonly cluster: string;
    readonly user: string;
    readonly name: string;
    readonly namespace?: string;
}
export declare function newContexts(a: any, opts?: Partial<ConfigOptions>): Context[];
export declare function exportContext(ctx: Context): any;
