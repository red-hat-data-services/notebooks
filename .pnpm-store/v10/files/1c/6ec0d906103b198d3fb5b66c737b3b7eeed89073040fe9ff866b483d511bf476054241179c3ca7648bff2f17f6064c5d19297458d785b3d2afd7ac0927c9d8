import { KubeConfig } from './config.js';
import { RequestOptions } from 'node:https';
export declare class Health {
    config: KubeConfig;
    constructor(config: KubeConfig);
    readyz(opts: RequestOptions): Promise<boolean>;
    livez(opts: RequestOptions): Promise<boolean>;
    private healthz;
    private check;
}
