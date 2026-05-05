import querystring from 'node:querystring';
import { isResizable, TerminalSizeQueue } from './terminal-size-queue.js';
import { WebSocketHandler } from './web-socket-handler.js';
export class Attach {
    constructor(config, websocketInterface) {
        this.handler = websocketInterface || new WebSocketHandler(config);
    }
    async attach(namespace, podName, containerName, stdout, stderr, stdin, tty) {
        const query = {
            container: containerName,
            stderr: stderr != null,
            stdin: stdin != null,
            stdout: stdout != null,
            tty,
        };
        const queryStr = querystring.stringify(query);
        const path = `/api/v1/namespaces/${namespace}/pods/${podName}/attach?${queryStr}`;
        const conn = await this.handler.connect(path, null, (streamNum, buff) => {
            WebSocketHandler.handleStandardStreams(streamNum, buff, stdout, stderr);
            return true;
        });
        if (stdin != null) {
            WebSocketHandler.handleStandardInput(conn, stdin, WebSocketHandler.StdinStream);
        }
        if (isResizable(stdout)) {
            this.terminalSizeQueue = new TerminalSizeQueue();
            WebSocketHandler.handleStandardInput(conn, this.terminalSizeQueue, WebSocketHandler.ResizeStream);
            this.terminalSizeQueue.handleResizes(stdout);
        }
        return conn;
    }
}
//# sourceMappingURL=attach.js.map