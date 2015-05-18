classdef EpochTT < GenericTimeArray
	%EpochTT Class representing Terrestrial Time epoch
	%
	% EpochTT(t) - initialize class whith time vector t
	%               - vector of seconds (double)
	%               - vector of nanoseconds (int64) / used in CDF Epoch
	%               - UTC string array
	
	methods
		function obj = EpochTT(inp)
			if nargin==0, return, end
			if isa(inp,'double'),
				if min(size(inp))>1
					error('irf:EpochTT:EpochTT:badInputs',...
						'input must be a column or row vector')
				end
				obj.epoch = int64(inp(:)*1e9); % column vector
			elseif isa(inp,'int64'),
				if min(size(inp))>1
					error('irf:EpochTT:EpochTT:badInputs',...
						'input must be a column or row vector')
				end
				obj.epoch = inp(:); % column vector
			elseif isa(inp,'char')
				if ~GenericTimeArray.validate_utc_time_str(inp)
					error('irf:EpochUnix:EpochUnix:badInputs',...
						'UTC string input (char) must be in the form yyyy-mm-ddThh:mm:ss.mmmuuunnnZ')
				end
				obj.epoch = irf_time(inp,'utc>ttns');
			else
				error('irf:EpochUnix:EpochUnix:badInputs',...
					'Expected inputs: int64 (nanoseconds since 2000), double (seconds since 1970) or char (yyyy-mm-ddThh:mm:ss.mmmuuunnnZ)')
			end
		end
		function out = epochUnix(obj)
			out = irf_time(obj.epoch,'ttns>epoch');
		end
		function s = toUtc(obj)
			s = utc(obj);
		end
		function s = utc(obj,format)
			% s = toUtc(obj,format)
			if nargin<2,
				format = '';
			else
				format = ['_' format];
			end
			s = irf_time(obj.epoch,['ttns>utc' format]);
		end
		function s = t(obj,varargin)
			% s = t(obj,index) same as tt(obj,index)
			s = tt(obj,varargin{:});
		end
		function s = tt(obj,index)
			% s = tt(obj,index)
			% return index points, if not given return all
			if nargin == 1,
				s = double(obj.epoch)/1e9;
			elseif nargin == 2 && isnumeric(index),
				s = double(obj.epoch(index))/1e9;
			end
		end
		function s = ttns(obj,index)
			% s = ttns(obj,index)
			if nargin == 1,
				s = obj.epoch;
			elseif nargin == 2 && isnumeric(index),
				s = obj.epoch(index);
			end
		end
		
		function objOut = plus(obj,arg)
			if isnumeric(arg)
				if isa(arg,'double'),
					inp = int64(arg*1e9);
				elseif isa(arg,'integer'),
					inp = arg;
				else
					error('Input type not defined');
				end
				objOut = obj;
				objOut.epoch = obj.epoch + inp(:);
			end
		end
		function out = minus(obj,arg)
			if isnumeric(arg),
				if isa(arg,'double'),
					inp = int64(arg*1e9);
				elseif isa(arg,'integer'),
					inp = arg;
				else
					error('Input type not defined');
				end
				out = obj;
				out.epoch = obj.epoch - inp(:);
			elseif isa(arg,'EpochTT'),
				out = double(obj.epoch - arg.epoch)/1e9;
			end
		end
	end
end