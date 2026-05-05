import { ListWatch } from './cache.js';
import { Watch } from './watch.js';
// These are issued per object
export const ADD = 'add';
export const UPDATE = 'update';
export const CHANGE = 'change';
export const DELETE = 'delete';
// This is issued when a watch connects or reconnects
export const CONNECT = 'connect';
// This is issued when there is an error
export const ERROR = 'error';
export function makeInformer(kubeconfig, path, listPromiseFn, labelSelector) {
    const watch = new Watch(kubeconfig);
    return new ListWatch(path, watch, listPromiseFn, false, labelSelector);
}
//# sourceMappingURL=informer.js.map