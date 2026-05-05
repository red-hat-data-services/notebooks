import { ObjectSerializer as InternalSerializer } from './gen/models/ObjectSerializer.js';
const isKubernetesObject = (data) => !!data && typeof data === 'object' && 'apiVersion' in data && 'kind' in data;
class KubernetesObject {
    serialize() {
        const instance = {};
        for (const attributeType of KubernetesObject.attributeTypeMap) {
            const value = this[attributeType.baseName];
            if (value !== undefined) {
                instance[attributeType.name] = InternalSerializer.serialize(this[attributeType.baseName], attributeType.type, attributeType.format);
            }
        }
        // add all unknown properties as is.
        for (const [key, value] of Object.entries(this)) {
            if (KubernetesObject.attributeTypeMap.find((t) => t.name === key)) {
                continue;
            }
            instance[key] = value;
        }
        return instance;
    }
    static fromUnknown(data) {
        if (!isKubernetesObject(data)) {
            throw new Error(`Unable to deseriliaze non-Kubernetes object ${data}.`);
        }
        const instance = new KubernetesObject();
        for (const attributeType of KubernetesObject.attributeTypeMap) {
            const value = data[attributeType.baseName];
            if (value !== undefined) {
                instance[attributeType.name] = InternalSerializer.deserialize(data[attributeType.baseName], attributeType.type, attributeType.format);
            }
        }
        // add all unknown properties as is.
        for (const [key, value] of Object.entries(data)) {
            if (KubernetesObject.attributeTypeMap.find((t) => t.name === key)) {
                continue;
            }
            instance[key] = value;
        }
        return instance;
    }
}
KubernetesObject.attributeTypeMap = [
    {
        name: 'apiVersion',
        baseName: 'apiVersion',
        type: 'string',
        format: '',
    },
    {
        name: 'kind',
        baseName: 'kind',
        type: 'string',
        format: '',
    },
    {
        name: 'metadata',
        baseName: 'metadata',
        type: 'V1ObjectMeta',
        format: '',
    },
];
const gvString = ({ group, version }) => [group, version].join('/');
const gvkFromObject = (obj) => {
    const [g, v] = obj.apiVersion.split('/');
    return {
        kind: obj.kind,
        group: v ? g : '',
        version: v ? v : g,
    };
};
/**
 * Default serializer that uses the KubernetesObject to serialize and deserialize
 * any object using only the minimum required attributes.
 */
export const defaultSerializer = {
    serialize: (data, type, format) => {
        if (data instanceof KubernetesObject) {
            return data.serialize();
        }
        return KubernetesObject.fromUnknown(data).serialize();
    },
    deserialize: (data, type, format) => {
        return KubernetesObject.fromUnknown(data);
    },
};
/**
 * Wraps the ObjectSerializer to support custom resources and generic Kubernetes objects.
 *
 * CustomResources that are unknown to the ObjectSerializer can be registered
 * by using ObjectSerializer.registerModel().
 */
export class ObjectSerializer extends InternalSerializer {
    /**
     * Adds a dedicated seriliazer for a Kubernetes resource.
     * Every resource is uniquly identified using its group, version and kind.
     * @param gvk
     * @param serializer
     */
    static registerModel(gvk, serializer) {
        var _a;
        var _b;
        const gv = gvString(gvk);
        const kinds = ((_a = (_b = this.modelRegistry)[gv]) !== null && _a !== void 0 ? _a : (_b[gv] = {}));
        if (kinds[gvk.kind]) {
            throw new Error(`Kind ${gvk.kind} of ${gv} is already defined`);
        }
        kinds[gvk.kind] = serializer;
    }
    /**
     * Removes all registered models from the registry.
     */
    static clearModelRegistry() {
        this.modelRegistry = {};
    }
    static getSerializerForObject(obj) {
        var _a;
        if (!isKubernetesObject(obj)) {
            return undefined;
        }
        const gvk = gvkFromObject(obj);
        return (_a = ObjectSerializer.modelRegistry[gvString(gvk)]) === null || _a === void 0 ? void 0 : _a[gvk.kind];
    }
    static serialize(data, type, format = '') {
        const serializer = ObjectSerializer.getSerializerForObject(data);
        if (serializer) {
            return serializer.serialize(data, type, format);
        }
        if (data instanceof KubernetesObject) {
            return data.serialize();
        }
        const obj = InternalSerializer.serialize(data, type, format);
        if (obj !== data) {
            return obj;
        }
        if (!isKubernetesObject(data)) {
            return obj;
        }
        const instance = {};
        for (const attributeType of KubernetesObject.attributeTypeMap) {
            const value = data[attributeType.baseName];
            if (value !== undefined) {
                instance[attributeType.name] = InternalSerializer.serialize(data[attributeType.baseName], attributeType.type, attributeType.format);
            }
        }
        // add all unknown properties as is.
        for (const [key, value] of Object.entries(data)) {
            if (KubernetesObject.attributeTypeMap.find((t) => t.name === key)) {
                continue;
            }
            instance[key] = value;
        }
        return instance;
    }
    static deserialize(data, type, format = '') {
        const serializer = ObjectSerializer.getSerializerForObject(data);
        if (serializer) {
            return serializer.deserialize(data, type, format);
        }
        const obj = InternalSerializer.deserialize(data, type, format);
        if (obj !== data) {
            // the serializer knows the type and already deserialized it.
            return obj;
        }
        if (!isKubernetesObject(data)) {
            return obj;
        }
        return KubernetesObject.fromUnknown(data);
    }
}
ObjectSerializer.modelRegistry = {};
//# sourceMappingURL=serializer.js.map