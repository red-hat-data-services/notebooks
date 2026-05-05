import querystring from 'node:querystring';
import { WebSocketHandler } from './web-socket-handler.js';
export class PortForward {
    // handler is a parameter really only for injecting for testing.
    constructor(config, disconnectOnErr, handler) {
        this.handler = handler || new WebSocketHandler(config);
        this.disconnectOnErr = disconnectOnErr === undefined ? true : disconnectOnErr;
    }
    // TODO: support multiple ports for real...
    async portForward(namespace, podName, targetPorts, output, err, input, retryCount = 0) {
        if (targetPorts.length === 0) {
            throw new Error('You must provide at least one port to forward to.');
        }
        if (targetPorts.length > 1) {
            throw new Error('Only one port is currently supported for port-forward');
        }
        const query = {
            ports: targetPorts[0],
        };
        const queryStr = querystring.stringify(query);
        const needsToReadPortNumber = [];
        targetPorts.forEach((value, index) => {
            needsToReadPortNumber[index * 2] = true;
            needsToReadPortNumber[index * 2 + 1] = true;
        });
        const path = `/api/v1/namespaces/${namespace}/pods/${podName}/portforward?${queryStr}`;
        const createWebSocket = () => {
            return this.handler.connect(path, null, (streamNum, buff) => {
                if (streamNum >= targetPorts.length * 2) {
                    return !this.disconnectOnErr;
                }
                // First two bytes of each stream are the port number
                if (needsToReadPortNumber[streamNum]) {
                    buff = buff.slice(2);
                    needsToReadPortNumber[streamNum] = false;
                }
                if (streamNum % 2 === 1) {
                    if (err) {
                        err.write(buff);
                    }
                }
                else {
                    output.write(buff);
                }
                return true;
            });
        };
        if (retryCount < 1) {
            const ws = await createWebSocket();
            WebSocketHandler.handleStandardInput(ws, input, 0);
            return ws;
        }
        return WebSocketHandler.restartableHandleStandardInput(createWebSocket, input, 0, retryCount);
    }
}
//# sourceMappingURL=portforward.js.map