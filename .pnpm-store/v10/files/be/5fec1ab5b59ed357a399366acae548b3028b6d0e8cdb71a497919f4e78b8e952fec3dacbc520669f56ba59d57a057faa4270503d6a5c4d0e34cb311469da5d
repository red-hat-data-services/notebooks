import { ObjectSerializer as InternalSerializer } from './gen/models/ObjectSerializer.js';
export interface Serializer {
    serialize(data: any, type: string, format?: string): any;
    deserialize(data: any, type: string, format?: any): any;
}
export type GroupVersionKind = {
    group: string;
    version: string;
    kind: string;
};
/**
 * Default serializer that uses the KubernetesObject to serialize and deserialize
 * any object using only the minimum required attributes.
 */
export declare const defaultSerializer: Serializer;
/**
 * Wraps the ObjectSerializer to support custom resources and generic Kubernetes objects.
 *
 * CustomResources that are unknown to the ObjectSerializer can be registered
 * by using ObjectSerializer.registerModel().
 */
export declare class ObjectSerializer extends InternalSerializer {
    private static modelRegistry;
    /**
     * Adds a dedicated seriliazer for a Kubernetes resource.
     * Every resource is uniquly identified using its group, version and kind.
     * @param gvk
     * @param serializer
     */
    static registerModel(gvk: GroupVersionKind, serializer: Serializer): void;
    /**
     * Removes all registered models from the registry.
     */
    static clearModelRegistry(): void;
    private static getSerializerForObject;
    static serialize(data: any, type: string, format?: string): any;
    static deserialize(data: any, type: string, format?: string): any;
}
