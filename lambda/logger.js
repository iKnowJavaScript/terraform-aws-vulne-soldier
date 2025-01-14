// Logger
const LogLevel = {
  none: 0,
  error: 10,
  info: 20,
  debug: 30,
};

class Logger {
  constructor(logLevel) {}

  error(...args) {
    if (this.logLevel >= LogLevel.error) {
      console.error(...args);
    }
  }
  info(...args) {
    if (this.logLevel >= LogLevel.info) {
      console.log(...args);
    }
  }
  debug(...args) {
    if (this.logLevel >= LogLevel.debug) {
      console.trace(...args);
    }
  }
}

const logLevel =
  {
    ERROR: LogLevel.error,
    INFO: LogLevel.info,
    DEBUG: LogLevel.debug,
  }[process.env.LOG_LEVEL ?? "NONE"] ?? LogLevel.none;
  
export let logger = new Logger(logLevel);