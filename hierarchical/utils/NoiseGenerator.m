% filepath: c:\Users\srseb\OneDrive\School\FSU\Fall 2025\Symbolic Numeric Computation w Alan Lemmon\New_Project1\dual_hierarchy\hierarchical\utils\NoiseGenerator.m

classdef NoiseGenerator < handle
    % NOISEGENERATOR Generates sensory noise for observations
    
    properties
        noise_type          % 'gaussian', 'uniform', 'none'
        seed                % Random seed for reproducibility
    end
    
    methods
        function obj = NoiseGenerator(noise_type, seed)
            if nargin < 1
                obj.noise_type = 'gaussian';
            else
                obj.noise_type = noise_type;
            end
            
            if nargin < 2
                obj.seed = [];
            else
                obj.seed = seed;
                rng(seed);  % Set seed for reproducibility
            end
        end
        
        function noisy_obs = addNoise(obj, observation, noise_std)
            % Add noise to observation based on noise type
            
            if noise_std <= 0 || strcmp(obj.noise_type, 'none')
                noisy_obs = observation;
                return;
            end
            
            switch obj.noise_type
                case 'gaussian'
                    % Gaussian noise: N(0, noise_std)
                    noise = randn(size(observation)) * noise_std;
                    noisy_obs = observation + noise;
                    
                case 'uniform'
                    % Uniform noise: U(-noise_std, noise_std)
                    noise = (rand(size(observation)) - 0.5) * 2 * noise_std;
                    noisy_obs = observation + noise;
                    
                case 'salt_and_pepper'
                    % Salt and pepper noise (occasional spikes)
                    noisy_obs = observation;
                    spike_prob = 0.01;  % 1% spike probability
                    spike_mask = rand(size(observation)) < spike_prob;
                    noisy_obs(spike_mask) = noisy_obs(spike_mask) + randn(sum(spike_mask(:)), 1) * noise_std * 5;
                    
                otherwise
                    error('Unknown noise type: %s', obj.noise_type);
            end
        end
        
        function [x_noisy, y_noisy, z_noisy] = addPositionNoise(obj, x, y, z, pos_noise_std)
            % Add noise to position observation
            pos = [x; y; z];
            noisy_pos = obj.addNoise(pos, pos_noise_std);
            x_noisy = noisy_pos(1);
            y_noisy = noisy_pos(2);
            z_noisy = noisy_pos(3);
        end
        
        function [vx_noisy, vy_noisy, vz_noisy] = addVelocityNoise(obj, vx, vy, vz, vel_noise_std)
            % Add noise to velocity observation
            vel = [vx; vy; vz];
            noisy_vel = obj.addNoise(vel, vel_noise_std);
            vx_noisy = noisy_vel(1);
            vy_noisy = noisy_vel(2);
            vz_noisy = noisy_vel(3);
        end
    end
end