// Logger utility for consistent logging across the application

// Define log levels
export enum LogLevel {
  NONE = 0,
  ERROR = 1,
  WARN = 2,
  INFO = 3,
  DEBUG = 4
}

// Logger class for better logging control
export class Logger {
  private level: LogLevel;
  private prefix: string;

  constructor(level: LogLevel = LogLevel.INFO, prefix: string = '') {
    this.level = level;
    this.prefix = prefix ? `[${prefix}] ` : '';
  }

  setLevel(level: LogLevel) {
    this.level = level;
  }

  getLevel(): LogLevel {
    return this.level;
  }

  setPrefix(prefix: string) {
    this.prefix = prefix ? `[${prefix}] ` : '';
  }

  debug(message: string | any) {
    if (this.level >= LogLevel.DEBUG) {
      if (typeof message === 'string') {
        console.log(`${this.prefix}[DEBUG] ${message}`);
      } else {
        console.log(`${this.prefix}[DEBUG]`, message);
      }
    }
  }

  info(message: string | any) {
    if (this.level >= LogLevel.INFO) {
      if (typeof message === 'string') {
        console.log(`${this.prefix}[INFO] ${message}`);
      } else {
        console.log(`${this.prefix}[INFO]`, message);
      }
    }
  }

  warn(message: string | any) {
    if (this.level >= LogLevel.WARN) {
      if (typeof message === 'string') {
        console.warn(`${this.prefix}[WARN] ${message}`);
      } else {
        console.warn(`${this.prefix}[WARN]`, message);
      }
    }
  }

  error(message: string | any, error?: any) {
    if (this.level >= LogLevel.ERROR) {
      if (typeof message === 'string') {
        console.error(`${this.prefix}[ERROR] ${message}`);
        if (error) {
          console.error(error);
        }
      } else {
        console.error(`${this.prefix}[ERROR]`, message);
      }
    }
  }

  // Utility method to log performance metrics
  timing(label: string, startTime: number) {
    if (this.level >= LogLevel.DEBUG) {
      const duration = Date.now() - startTime;
      console.log(`${this.prefix}[TIMING] ${label}: ${duration}ms`);
    }
  }
}

// Create a default logger instance
export const defaultLogger = new Logger();

// Helper function to create a logger with a specific context
export function createLogger(context: string, level: LogLevel = LogLevel.INFO): Logger {
  return new Logger(level, context);
}

// Simple log function that uses the default logger
export function log(message: string | any, level: LogLevel = LogLevel.INFO) {
  switch (level) {
    case LogLevel.ERROR:
      defaultLogger.error(message);
      break;
    case LogLevel.WARN:
      defaultLogger.warn(message);
      break;
    case LogLevel.INFO:
      defaultLogger.info(message);
      break;
    case LogLevel.DEBUG:
      defaultLogger.debug(message);
      break;
    default:
      break;
  }
} 