import { add, podsForNode, quantityToScalar, totalCPU, totalCPUForContainer, totalMemory, totalMemoryForContainer, } from './util.js';
export class ResourceUsage {
    constructor(Capacity, RequestTotal, LimitTotal) {
        this.Capacity = Capacity;
        this.RequestTotal = RequestTotal;
        this.LimitTotal = LimitTotal;
    }
}
export class CurrentResourceUsage {
    constructor(CurrentUsage, RequestTotal, LimitTotal) {
        this.CurrentUsage = CurrentUsage;
        this.RequestTotal = RequestTotal;
        this.LimitTotal = LimitTotal;
    }
}
export class NodeStatus {
    constructor(Node, CPU, Memory) {
        this.Node = Node;
        this.CPU = CPU;
        this.Memory = Memory;
    }
}
export class ContainerStatus {
    constructor(Container, CPUUsage, MemoryUsage) {
        this.Container = Container;
        this.CPUUsage = CPUUsage;
        this.MemoryUsage = MemoryUsage;
    }
}
export class PodStatus {
    constructor(Pod, CPU, Memory, Containers) {
        this.Pod = Pod;
        this.CPU = CPU;
        this.Memory = Memory;
        this.Containers = Containers;
    }
}
export async function topNodes(api) {
    // TODO: Support metrics APIs in the client and this library
    const nodes = await api.listNode();
    const result = [];
    for (const node of nodes.items) {
        const availableCPU = quantityToScalar(node.status.allocatable.cpu);
        const availableMem = quantityToScalar(node.status.allocatable.memory);
        let totalPodCPU = 0;
        let totalPodCPULimit = 0;
        let totalPodMem = 0;
        let totalPodMemLimit = 0;
        let pods = await podsForNode(api, node.metadata.name);
        pods = pods.filter((pod) => pod.status.phase === 'Running');
        pods.forEach((pod) => {
            const cpuTotal = totalCPU(pod);
            totalPodCPU = add(totalPodCPU, cpuTotal.request);
            totalPodCPULimit = add(totalPodCPULimit, cpuTotal.limit);
            const memTotal = totalMemory(pod);
            totalPodMem = add(totalPodMem, memTotal.request);
            totalPodMemLimit = add(totalPodMemLimit, memTotal.limit);
        });
        const cpuUsage = new ResourceUsage(availableCPU, totalPodCPU, totalPodCPULimit);
        const memUsage = new ResourceUsage(availableMem, totalPodMem, totalPodMemLimit);
        result.push(new NodeStatus(node, cpuUsage, memUsage));
    }
    return result;
}
// Returns the current pod CPU/Memory usage including the CPU/Memory usage of each container
export async function topPods(api, metrics, namespace) {
    // Figure out which pod list endpoint to call
    const getPodList = async () => {
        if (namespace) {
            return await api.listNamespacedPod({ namespace });
        }
        return await api.listPodForAllNamespaces();
    };
    const [podMetrics, podList] = await Promise.all([metrics.getPodMetrics(namespace), getPodList()]);
    // Create a map of pod names to their metric usage
    // to make it easier to look up when we need it later
    const podMetricsMap = podMetrics.items.reduce((accum, next) => {
        accum.set(next.metadata.name, next);
        return accum;
    }, new Map());
    const result = [];
    for (const pod of podList.items) {
        const podMetric = podMetricsMap.get(pod.metadata.name);
        const containerStatuses = [];
        let currentPodCPU = 0;
        let currentPodMem = 0;
        let podRequestsCPU = 0;
        let podLimitsCPU = 0;
        let podRequestsMem = 0;
        let podLimitsMem = 0;
        pod.spec.containers.forEach((container) => {
            // get the the container CPU/Memory container.resources.requests/limits
            const containerCpuTotal = totalCPUForContainer(container);
            const containerMemTotal = totalMemoryForContainer(container);
            // sum each container's CPU/Memory container.resources.requests/limits
            // to get the pod's overall requests/limits
            podRequestsCPU = add(podRequestsCPU, containerCpuTotal.request);
            podLimitsCPU = add(podLimitsCPU, containerCpuTotal.limit);
            podRequestsMem = add(podLimitsMem, containerMemTotal.request);
            podLimitsMem = add(podLimitsMem, containerMemTotal.limit);
            // Find the container metrics by container.name
            // if both the pod and container metrics exist
            const containerMetrics = podMetric !== undefined
                ? podMetric.containers.find((c) => c.name === container.name)
                : undefined;
            // Store the current usage of each container
            // Sum each container to get the overall pod usage
            if (containerMetrics !== undefined) {
                const currentContainerCPUUsage = quantityToScalar(containerMetrics.usage.cpu);
                const currentContainerMemUsage = quantityToScalar(containerMetrics.usage.memory);
                currentPodCPU = add(currentPodCPU, currentContainerCPUUsage);
                currentPodMem = add(currentPodMem, currentContainerMemUsage);
                const containerCpuUsage = new CurrentResourceUsage(currentContainerCPUUsage, containerCpuTotal.request, containerCpuTotal.limit);
                const containerMemUsage = new CurrentResourceUsage(currentContainerMemUsage, containerMemTotal.request, containerMemTotal.limit);
                containerStatuses.push(new ContainerStatus(containerMetrics.name, containerCpuUsage, containerMemUsage));
            }
        });
        const podCpuUsage = new CurrentResourceUsage(currentPodCPU, podRequestsCPU, podLimitsCPU);
        const podMemUsage = new CurrentResourceUsage(currentPodMem, podRequestsMem, podLimitsMem);
        result.push(new PodStatus(pod, podCpuUsage, podMemUsage, containerStatuses));
    }
    return result;
}
//# sourceMappingURL=top.js.map