classdef Logger < handle
    % LOGGER Structured logging with levels
    
    properties
        level
        file_handle
        console_output
    end
    
    properties (Constant)
        DEBUG = 0
        INFO = 1
        WARN = 2
        ERROR = 3
    end
    
    methods
        function obj = Logger(level_str, log_file)
            % Constructor
            %   level_str: 'DEBUG', 'INFO', 'WARN', 'ERROR'
            %   log_file: optional file path for log output
            
            switch upper(level_str)
                case 'DEBUG'
                    obj.level = Logger.DEBUG;
                case 'INFO'
                    obj.level = Logger.INFO;
                case 'WARN'
                    obj.level = Logger.WARN;
                case 'ERROR'
                    obj.level = Logger.ERROR;
                otherwise
                    obj.level = Logger.INFO;
            end
            
            obj.console_output = true;
            obj.file_handle = [];
            
            if nargin > 1 && ~isempty(log_file)
                obj.file_handle = fopen(log_file, 'w');
            end
        end
        
        function delete(obj)
            if ~isempty(obj.file_handle)
                fclose(obj.file_handle);
            end
        end
        
        function debug(obj, msg, varargin)
            if obj.level <= Logger.DEBUG
                obj.write('DEBUG', msg, varargin{:});
            end
        end
        
        function info(obj, msg, varargin)
            if obj.level <= Logger.INFO
                obj.write('INFO', msg, varargin{:});
            end
        end
        
        function warn(obj, msg, varargin)
            if obj.level <= Logger.WARN
                obj.write('WARN', msg, varargin{:});
            end
        end
        
        function error(obj, msg, varargin)
            if obj.level <= Logger.ERROR
                obj.write('ERROR', msg, varargin{:});
            end
        end
        
        function write(obj, level_str, msg, varargin)
            % Format and write log message
            formatted_msg = sprintf(msg, varargin{:});
            timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
            log_line = sprintf('[%s] %s: %s\n', timestamp, level_str, formatted_msg);
            
            % Console output
            if obj.console_output
                fprintf(log_line);
            end
            
            % File output
            if ~isempty(obj.file_handle)
                fprintf(obj.file_handle, log_line);
            end
        end
    end
end