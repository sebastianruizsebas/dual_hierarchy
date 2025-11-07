classdef PlanningHierarchy < NeuralHierarchy
    % PLANNINGHIERARCHY Planning-specific predictive coding hierarchy
    %   Extends NeuralHierarchy with task-indexed weights
    %   - Multiple weight sets (one per task)
    %   - Task-conditional learning
    %   - Target motion prediction
    
    properties
        % Task-indexed weight matrices (cell arrays)
        W_L3_to_L2_tasks  % {n_tasks} of (n_L2 x n_L3)
        W_L2_to_L1_tasks  % {n_tasks} of (n_L1 x n_L2)
        
        % Cached transposes (cell arrays)
        W_L3_to_L2_T_tasks
        W_L2_to_L1_T_tasks
        
        % Task-indexed momentum
        dW_L3_to_L2_prev_tasks
        dW_L2_to_L1_prev_tasks
        
        % Task management
        n_tasks
        current_task_idx
        
        % Semantic indices (same as motor for compatibility)
        idx_pos
        idx_vel
        idx_bias
    end
    
    methods
        function obj = PlanningHierarchy(config)
            % Call parent constructor
            obj@NeuralHierarchy(config, 'planning');
            
            % Task configuration
            obj.n_tasks = config.n_tasks;
            obj.current_task_idx = 1;
            
            % Semantic indices
            obj.idx_pos = config.idx_pos;
            obj.idx_vel = config.idx_vel;
            obj.idx_bias = config.idx_bias;
            
            % Initialize task-indexed weights
            obj.initializeTaskWeights();
        end
        
        function initializeTaskWeights(obj)
            % Initialize separate weight matrices for each task
            
            obj.W_L3_to_L2_tasks = cell(obj.n_tasks, 1);
            obj.W_L2_to_L1_tasks = cell(obj.n_tasks, 1);
            obj.W_L3_to_L2_T_tasks = cell(obj.n_tasks, 1);
            obj.W_L2_to_L1_T_tasks = cell(obj.n_tasks, 1);
            obj.dW_L3_to_L2_prev_tasks = cell(obj.n_tasks, 1);
            obj.dW_L2_to_L1_prev_tasks = cell(obj.n_tasks, 1);
            
            % Xavier initialization for each task
            scale_32 = sqrt(2.0 / (obj.n_L3 + obj.n_L2));
            scale_21 = sqrt(2.0 / (obj.n_L2 + obj.n_L1));
            
            for task = 1:obj.n_tasks
                obj.W_L3_to_L2_tasks{task} = scale_32 * randn(obj.n_L2, obj.n_L3, 'single');
                obj.W_L2_to_L1_tasks{task} = scale_21 * randn(obj.n_L1, obj.n_L2, 'single');
                
                obj.W_L3_to_L2_T_tasks{task} = obj.W_L3_to_L2_tasks{task}';
                obj.W_L2_to_L1_T_tasks{task} = obj.W_L2_to_L1_tasks{task}';
                
                obj.dW_L3_to_L2_prev_tasks{task} = zeros(obj.n_L2, obj.n_L3, 'single');
                obj.dW_L2_to_L1_prev_tasks{task} = zeros(obj.n_L1, obj.n_L2, 'single');
            end
        end
        
        function setTask(obj, task_idx)
            % Switch active task (loads appropriate weight matrices)
            assert(task_idx >= 1 && task_idx <= obj.n_tasks, ...
                'Invalid task index');
            
            obj.current_task_idx = task_idx;
            
            % Load weights for current task into parent class properties
            obj.W_L3_to_L2 = obj.W_L3_to_L2_tasks{task_idx};
            obj.W_L2_to_L1 = obj.W_L2_to_L1_tasks{task_idx};
            obj.W_L3_to_L2_T = obj.W_L3_to_L2_T_tasks{task_idx};
            obj.W_L2_to_L1_T = obj.W_L2_to_L1_T_tasks{task_idx};
            obj.dW_L3_to_L2_prev = obj.dW_L3_to_L2_prev_tasks{task_idx};
            obj.dW_L2_to_L1_prev = obj.dW_L2_to_L1_prev_tasks{task_idx};
        end
        
        function updateWeights(obj)
            % Override parent: update only current task's weights
            
            if obj.frozen
                return;
            end
            
            % Call parent's weight update (updates obj.W_* matrices)
            updateWeights@NeuralHierarchy(obj);
            
            % Save updated weights back to task-indexed storage
            task_idx = obj.current_task_idx;
            obj.W_L3_to_L2_tasks{task_idx} = obj.W_L3_to_L2;
            obj.W_L2_to_L1_tasks{task_idx} = obj.W_L2_to_L1;
            obj.W_L3_to_L2_T_tasks{task_idx} = obj.W_L3_to_L2_T;
            obj.W_L2_to_L1_T_tasks{task_idx} = obj.W_L2_to_L1_T;
            obj.dW_L3_to_L2_prev_tasks{task_idx} = obj.dW_L3_to_L2_prev;
            obj.dW_L2_to_L1_prev_tasks{task_idx} = obj.dW_L2_to_L1_prev;
        end
        
        function setTargetObservation(obj, x_target, y_target, z_target)
            % Observe target position (sensory input at L1)
            obj.R_L1(obj.idx_pos) = [x_target, y_target, z_target];
        end
        
        function [x_pred, y_pred, z_pred] = predictTargetPosition(obj)
            % Get planning hierarchy's prediction of target position
            pos_pred = obj.pred_L1(obj.idx_pos);
            x_pred = pos_pred(1);
            y_pred = pos_pred(2);
            z_pred = pos_pred(3);
        end
    end
end