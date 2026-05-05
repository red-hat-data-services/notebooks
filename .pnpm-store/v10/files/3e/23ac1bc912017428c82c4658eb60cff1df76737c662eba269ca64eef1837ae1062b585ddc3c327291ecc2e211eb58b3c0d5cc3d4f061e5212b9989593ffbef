import { Readable } from 'node:stream';
export class TerminalSizeQueue extends Readable {
    constructor(opts = {}) {
        super({
            ...opts,
            read() { },
        });
    }
    handleResizes(writeStream) {
        // Set initial size
        this.resize(getTerminalSize(writeStream));
        // Handle future size updates
        writeStream.on('resize', () => this.resize(getTerminalSize(writeStream)));
    }
    resize(size) {
        this.push(JSON.stringify(size));
    }
}
export function isResizable(stream) {
    if (stream == null) {
        return false;
    }
    const hasRows = 'rows' in stream;
    const hasColumns = 'columns' in stream;
    const hasOn = typeof stream.on === 'function';
    return hasRows && hasColumns && hasOn;
}
function getTerminalSize(writeStream) {
    return { height: writeStream.rows, width: writeStream.columns };
}
//# sourceMappingURL=terminal-size-queue.js.map