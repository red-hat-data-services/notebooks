import WebSocket from 'isomorphic-ws';
import stream from 'node:stream';
import { V1Status } from './api.js';
import { KubeConfig } from './config.js';
export interface WebSocketInterface {
    connect(path: string, textHandler: ((text: string) => boolean) | null, binaryHandler: ((stream: number, buff: Buffer) => boolean) | null): Promise<WebSocket.WebSocket>;
}
export interface StreamInterface {
    stdin: stream.Readable;
    stdout: stream.Writable;
    stderr: stream.Writable;
}
export declare class WebSocketHandler implements WebSocketInterface {
    static readonly StdinStream: number;
    static readonly StdoutStream: number;
    static readonly StderrStream: number;
    static readonly StatusStream: number;
    static readonly ResizeStream: number;
    static readonly CloseStream: number;
    static supportsClose(protocol: string): boolean;
    static closeStream(streamNum: number, streams: StreamInterface): void;
    static handleStandardStreams(streamNum: number, buff: Buffer, stdout: stream.Writable | null, stderr: stream.Writable | null): V1Status | null;
    static handleStandardInput(ws: WebSocket.WebSocket, stdin: stream.Readable, streamNum?: number): boolean;
    static processData(data: string | Buffer, ws: WebSocket.WebSocket | null, createWS: () => Promise<WebSocket.WebSocket>, streamNum?: number, retryCount?: number, encoding?: BufferEncoding | null): Promise<WebSocket.WebSocket | null>;
    static restartableHandleStandardInput(createWS: () => Promise<WebSocket.WebSocket>, stdin: stream.Readable, streamNum?: number, retryCount?: number, addFlushForTesting?: boolean): () => WebSocket.WebSocket | null;
    readonly config: KubeConfig;
    readonly socketFactory?: (uri: string, protocols: string[], opts: WebSocket.ClientOptions) => WebSocket.WebSocket;
    readonly streams: StreamInterface;
    constructor(kc: KubeConfig, socketFactoryFn?: (uri: string, protocols: string[], opts: WebSocket.ClientOptions) => WebSocket.WebSocket, streamsInterface?: StreamInterface);
    /**
     * Connect to a web socket endpoint.
     * @param path The HTTP Path to connect to on the server.
     * @param textHandler Callback for text over the web socket.
     *      Returns true if the connection should be kept alive, false to disconnect.
     * @param binaryHandler Callback for binary data over the web socket.
     *      Returns true if the connection should be kept alive, false to disconnect.
     */
    connect(path: string, textHandler: ((text: string) => boolean) | null, binaryHandler: ((stream: number, buff: Buffer) => boolean) | null): Promise<WebSocket.WebSocket>;
}
