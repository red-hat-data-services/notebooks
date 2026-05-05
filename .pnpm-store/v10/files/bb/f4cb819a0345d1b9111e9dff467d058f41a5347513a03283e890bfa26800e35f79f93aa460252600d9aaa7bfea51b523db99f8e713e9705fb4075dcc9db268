import { ADD, CHANGE, CONNECT, DELETE, ERROR, UPDATE, } from './informer.js';
import { ObjectSerializer } from './serializer.js';
export class ListWatch {
    constructor(path, watch, listFn, autoStart = true, labelSelector, fieldSelector) {
        this.objects = new Map();
        this.indexCache = {};
        this.callbackCache = {};
        this.stopped = false;
        this.path = path;
        this.watch = watch;
        this.listFn = listFn;
        this.labelSelector = labelSelector;
        this.fieldSelector = fieldSelector;
        this.callbackCache[ADD] = [];
        this.callbackCache[UPDATE] = [];
        this.callbackCache[DELETE] = [];
        this.callbackCache[ERROR] = [];
        this.callbackCache[CONNECT] = [];
        this.resourceVersion = '';
        if (autoStart) {
            this.doneHandler(null);
        }
    }
    async start() {
        this.stopped = false;
        await this.doneHandler(null);
    }
    async stop() {
        this.stopped = true;
        this._stop();
    }
    on(verb, cb) {
        if (verb === CHANGE) {
            this.on(ADD, cb);
            this.on(UPDATE, cb);
            this.on(DELETE, cb);
            return;
        }
        if (this.callbackCache[verb] === undefined) {
            throw new Error(`Unknown verb: ${verb}`);
        }
        this.callbackCache[verb].push(cb);
    }
    off(verb, cb) {
        if (verb === CHANGE) {
            this.off('add', cb);
            this.off('update', cb);
            this.off('delete', cb);
            return;
        }
        if (this.callbackCache[verb] === undefined) {
            throw new Error(`Unknown verb: ${verb}`);
        }
        const indexToRemove = this.callbackCache[verb].findIndex((cachedCb) => cachedCb === cb);
        if (indexToRemove === -1) {
            return;
        }
        this.callbackCache[verb].splice(indexToRemove, 1);
    }
    get(name, namespace) {
        const nsObjects = this.objects.get(namespace || '');
        if (nsObjects) {
            return nsObjects.get(name);
        }
        return undefined;
    }
    list(namespace) {
        if (!namespace) {
            const allObjects = [];
            for (const nsObjects of this.objects.values()) {
                allObjects.push(...nsObjects.values());
            }
            return allObjects;
        }
        const namespaceObjects = this.objects.get(namespace || '');
        if (!namespaceObjects) {
            return [];
        }
        return Array.from(namespaceObjects.values());
    }
    latestResourceVersion() {
        return this.resourceVersion;
    }
    _stop() {
        if (this.request) {
            this.request.abort();
            this.request = undefined;
        }
    }
    async doneHandler(err) {
        this._stop();
        if (err &&
            (err.statusCode === 410 || err.code === 410)) {
            this.resourceVersion = '';
        }
        else if (err) {
            this.callbackCache[ERROR].forEach((elt) => elt(err));
            return;
        }
        if (this.stopped) {
            // do not auto-restart
            return;
        }
        this.callbackCache[CONNECT].forEach((elt) => elt(undefined));
        if (!this.resourceVersion) {
            let list;
            try {
                const promise = this.listFn();
                list = await promise;
            }
            catch (err) {
                this.callbackCache[ERROR].forEach((elt) => elt(err));
                return;
            }
            this.objects = deleteItems(this.objects, list.items, this.callbackCache[DELETE].slice());
            this.addOrUpdateItems(list.items);
            this.resourceVersion = list.metadata ? list.metadata.resourceVersion || '' : '';
        }
        const queryParams = {
            resourceVersion: this.resourceVersion,
        };
        if (this.labelSelector !== undefined) {
            queryParams.labelSelector = ObjectSerializer.serialize(this.labelSelector, 'string');
        }
        if (this.fieldSelector !== undefined) {
            queryParams.fieldSelector = ObjectSerializer.serialize(this.fieldSelector, 'string');
        }
        this.request = await this.watch.watch(this.path, queryParams, this.watchHandler.bind(this), this.doneHandler.bind(this));
    }
    addOrUpdateItems(items) {
        if (items === undefined || items === null) {
            return;
        }
        items.forEach((obj) => {
            addOrUpdateObject(this.objects, obj, this.callbackCache[ADD].slice(), this.callbackCache[UPDATE].slice());
        });
    }
    async watchHandler(phase, obj, watchObj) {
        switch (phase) {
            case 'ERROR':
                if (obj.code === 410) {
                    this.resourceVersion = '';
                }
                // We don't restart here, because it should be handled by the watch exiting if necessary
                return;
            case 'ADDED':
            case 'MODIFIED':
                addOrUpdateObject(this.objects, obj, this.callbackCache[ADD].slice(), this.callbackCache[UPDATE].slice());
                break;
            case 'DELETED':
                deleteObject(this.objects, obj, this.callbackCache[DELETE].slice());
                break;
            case 'BOOKMARK':
                // nothing to do, here for documentation, mostly.
                break;
        }
        this.resourceVersion = obj.metadata ? obj.metadata.resourceVersion || '' : '';
    }
}
// exported for testing
export function cacheMapFromList(newObjects) {
    const objects = new Map();
    if (newObjects === undefined || newObjects === null) {
        return objects;
    }
    // build up the new list
    for (const obj of newObjects) {
        let namespaceObjects = objects.get(obj.metadata.namespace || '');
        if (!namespaceObjects) {
            namespaceObjects = new Map();
            objects.set(obj.metadata.namespace || '', namespaceObjects);
        }
        const name = obj.metadata.name || '';
        namespaceObjects.set(name, obj);
    }
    return objects;
}
// external for testing
export function deleteItems(oldObjects, newObjects, deleteCallback) {
    const newObjectsMap = cacheMapFromList(newObjects);
    for (const [namespace, oldNamespaceObjects] of oldObjects.entries()) {
        const newNamespaceObjects = newObjectsMap.get(namespace);
        if (newNamespaceObjects) {
            for (const [name, oldObj] of oldNamespaceObjects.entries()) {
                if (!newNamespaceObjects.has(name)) {
                    oldNamespaceObjects.delete(name);
                    if (deleteCallback) {
                        deleteCallback.forEach((fn) => fn(oldObj));
                    }
                }
            }
        }
        else {
            oldObjects.delete(namespace);
            oldNamespaceObjects.forEach((obj) => {
                if (deleteCallback) {
                    deleteCallback.forEach((fn) => fn(obj));
                }
            });
        }
    }
    return oldObjects;
}
// Only public for testing.
export function addOrUpdateObject(objects, obj, addCallbacks, updateCallbacks) {
    let namespaceObjects = objects.get(obj.metadata.namespace || '');
    if (!namespaceObjects) {
        namespaceObjects = new Map();
        objects.set(obj.metadata.namespace || '', namespaceObjects);
    }
    const name = obj.metadata.name || '';
    const found = namespaceObjects.get(name);
    if (!found) {
        namespaceObjects.set(name, obj);
        if (addCallbacks) {
            addCallbacks.forEach((elt) => elt(obj));
        }
    }
    else {
        if (!isSameVersion(found, obj)) {
            namespaceObjects.set(name, obj);
            if (updateCallbacks) {
                updateCallbacks.forEach((elt) => elt(obj));
            }
        }
    }
}
function isSameVersion(o1, o2) {
    return (o1.metadata.resourceVersion !== undefined &&
        o1.metadata.resourceVersion !== null &&
        o1.metadata.resourceVersion === o2.metadata.resourceVersion);
}
// Public for testing.
export function deleteObject(objects, obj, deleteCallbacks) {
    const namespace = obj.metadata.namespace || '';
    const name = obj.metadata.name || '';
    const namespaceObjects = objects.get(namespace);
    if (!namespaceObjects) {
        return;
    }
    const deleted = namespaceObjects.delete(name);
    if (deleted) {
        if (deleteCallbacks) {
            deleteCallbacks.forEach((elt) => elt(obj));
        }
        if (namespaceObjects.size === 0) {
            objects.delete(namespace);
        }
    }
}
//# sourceMappingURL=cache.js.map