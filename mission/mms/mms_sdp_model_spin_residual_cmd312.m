function [modelOut] = mms_sdp_model_spin_residual_cmd312(Dcv,Phase,sampleRate)
%MMS_SDP_MODEL_SPIN_RESIDUAL  create a spin residual
%
%  modelOut = mms_sdp_model_spin_residual(dce,dcv,phase,signals,sampleRate)
%
%  Created a model to a disturbace signal caused by the ADP shadow by
%  looking at many spins.
%
%  Input : DCE     - structure with fields time, e12, e34
%          DCV     - structure with fields time, v1, v2, v3, v4
%          PHASE   - phase corresponding to DCE time. 
%          SIGNALS - cell array with list of signals to proceess, 
%                    e.g {'e12', 'e34'} or {'v1', 'v3'}

% ----------------------------------------------------------------------------
% "THE BEER-WARE LICENSE" (Revision 42):
% <yuri@irfu.se> wrote this file.  As long as you retain this notice you
% can do whatever you want with this stuff. If we meet some day, and you think
% this stuff is worth it, you can buy me a beer in return.   Yuri Khotyaintsev
% ----------------------------------------------------------------------------

MMS_CONST = mms_constants;

%% compute model
epoch0 = Dcv.time(1); epochTmp = double(Dcv.time-epoch0);

% Spinfits setup
MAX_IT = 3;      % Maximum of iterations to run fit
N_TERMS = 3;     % Number of terms to fit, Y = A + B*sin(wt) + C*cos(wt) +..., must be odd.
MIN_FRAC = 0.20; % Minumum fraction of points required for one fit (minPts = minFraction * fitInterv [s] * samplerate [smpl/s] )
FIT_EVERY = 5*10^9;   % Fit every X nanoseconds.
FIT_INTERV = double(MMS_CONST.Limit.SPINFIT_INTERV); % Fit over X nanoseconds interval.

sdpPr = {'v1', 'v2','v3','v4'};
Sfit = struct(sdpPr{1}, [],sdpPr{2}, [], sdpPr{3}, [],sdpPr{4}, []);

% Calculate minumum number of points req. for one fit covering fitInterv
minPts = MIN_FRAC * sampleRate * FIT_INTERV/10^9; % "/10^9" as fitInterv is in [ns].

% Calculate first timestamp of spinfits to be after start of dce time
% and evenly divisable with fitEvery.
% I.e. if fitEvery = 5 s, then spinfit timestamps would be like
% [00.00.00; 00.00.05; 00.00.10; 00.00.15;] etc.
% For this one must rely on spdfbreakdowntt2000 as the TT2000 (int64)
% includes things like leap seconds.
t1 = spdfbreakdowntt2000(Dcv.time(1)); % Start time in format [YYYY MM DD HH MM ss mm uu nn]
% Evenly divisable timestamp with fitEvery after t1, in ns.
t2 = ceil((t1(6)*10^9+t1(7)*10^6+t1(8)*10^3+t1(9))/FIT_EVERY)*FIT_EVERY;
% Note; spdfcomputett2000 can handle any column greater than expected,
% ie "62 seconds" are re-calculated to "1 minute and 2 sec".
t3.sec = floor(t2/10^9);
t3.ms  = floor((t2-t3.sec*10^9)/10^6);
t3.us  = floor((t2-t3.sec*10^9-t3.ms*10^6)/10^3);
t3.ns  = floor(t2-t3.sec*10^9-t3.ms*10^6-t3.us*10^3);
% Compute what TT2000 time that corresponds to, using spdfcomputeTT2000.
t0 = spdfcomputett2000([t1(1) t1(2) t1(3) t1(4) t1(5) t3.sec t3.ms t3.us t3.ns]);
      
phaRad = unwrap(Phase.data*pi/180);

STEPS_PER_DEG = 1; phaShift=STEPS_PER_DEG/2;
phaDegUnw = phaRad*180/pi;
phaFixed = (fix(phaDegUnw(1)):STEPS_PER_DEG:fix(phaDegUnw(end)))' ...
  + phaShift;
pha360 = 0:STEPS_PER_DEG:360; pha360 = pha360' + phaShift; pha360(end) = [];
n360 = length(pha360);
timeTmp = interp1(phaDegUnw,epochTmp,phaFixed);
phaFixed(isnan(timeTmp)) = []; timeTmp(isnan(timeTmp)) = [];
phaFixedWrp = mod(phaFixed,360);

cmdRes = [];  
for signal = {'v1','v2','v3'}
  sig = signal{:};
  if isempty(intersect(signal,{'e12','e34','v1','v2','v3','v4'}))
    errS = ['invalid signal: ' sig]; irf.log('critical',errS), error(errS)
  end 
  
  phaseRadTmp = phaRad;
  if( (Dcv.time(1)<=t0) && (t0<=Dcv.time(end)))
    bits = MMS_CONST.Bitmask.SWEEP_DATA;
    dataIn = Dcv.(sig).data;
    dataIn = mask_bits(dataIn, Dcv.(sig).bitmask, bits);
    timeIn = Dcv.time;
    idxGood = ~isnan(dataIn);
    [tSfit, Sfit.(sig), ~, ~, ~] = ...
      mms_spinfit_m(MAX_IT, minPts, N_TERMS, double(timeIn(idxGood)),...
      double(dataIn(idxGood)), phaseRadTmp(idxGood), FIT_EVERY, FIT_INTERV, t0);
  else
    warnStr = sprintf(['Too short time series:'...
      ' no data cover first spinfit timestamp (t0=%i)'],t0);
    irf.log('warning', warnStr);
  end
  
  sfitR = interp1(double(tSfit-epoch0),Sfit.(sig),epochTmp);
  spinFitComponent = sfitR(:,1) + sfitR(:,2).*cos(phaRad) + sfitR(:,3).*sin(phaRad);
  
  spinRes = double(double(dataIn))-spinFitComponent;
  switch sig
    case 'v1', cmdRes = - 0.5*spinRes;
    case 'v2', cmdRes = cmdRes - 0.5*spinRes;
    case 'v3', cmdRes = cmdRes + spinRes;
    otherwise, error('should not be here')
  end
end
%%
cmdAv = [0.2392,...
    0.2259,...
    0.2124,...
    0.1960,...
    0.1808,...
    0.1661,...
    0.1507,...
    0.1361,...
    0.1212,...
    0.1062,...
    0.0913,...
    0.0751,...
    0.0603,...
    0.0446,...
    0.0293,...
    0.0138,...
   -0.0022,...
   -0.0183,...
   -0.0338,...
   -0.0500,...
   -0.0661,...
   -0.0844,...
   -0.0989,...
   -0.1143,...
   -0.1300,...
   -0.1451,...
   -0.1613,...
   -0.1747,...
   -0.1921,...
   -0.2082,...
   -0.2236,...
   -0.2394,...
   -0.2535,...
   -0.2697,...
   -0.2845,...
   -0.3016,...
   -0.3147,...
   -0.3302,...
   -0.3463,...
   -0.3602,...
   -0.3758,...
   -0.3915,...
   -0.4059,...
   -0.4207,...
   -0.4337,...
   -0.4483,...
   -0.4583,...
   -0.4703,...
   -0.4838,...
   -0.4922,...
   -0.5023,...
   -0.5115,...
   -0.5211,...
   -0.5295,...
   -0.5382,...
   -0.5438,...
   -0.5502,...
   -0.5549,...
   -0.5575,...
   -0.5552,...
   -0.5552,...
   -0.5561,...
   -0.5521,...
   -0.5457,...
   -0.5383,...
   -0.5329,...
   -0.5246,...
   -0.5144,...
   -0.5037,...
   -0.4945,...
   -0.4830,...
   -0.4725,...
   -0.4600,...
   -0.4488,...
   -0.4357,...
   -0.4243,...
   -0.4115,...
   -0.3981,...
   -0.3864,...
   -0.3695,...
   -0.3578,...
   -0.3444,...
   -0.3311,...
   -0.3175,...
   -0.3051,...
   -0.2912,...
   -0.2780,...
   -0.2639,...
   -0.2490,...
   -0.2348,...
   -0.2224,...
   -0.2068,...
   -0.1933,...
   -0.1785,...
   -0.1650,...
   -0.1499,...
   -0.1357,...
   -0.1199,...
   -0.1067,...
   -0.0914,...
   -0.0762,...
   -0.0618,...
   -0.0464,...
   -0.0313,...
   -0.0161,...
   -0.0014,...
    0.0137,...
    0.0292,...
    0.0446,...
    0.0600,...
    0.0757,...
    0.0915,...
    0.1043,...
    0.1214,...
    0.1370,...
    0.1531,...
    0.1683,...
    0.1828,...
    0.1971,...
    0.2107,...
    0.2281,...
    0.2419,...
    0.2581,...
    0.2742,...
    0.2889,...
    0.3033,...
    0.3175,...
    0.3318,...
    0.3459,...
    0.3592,...
    0.3743,...
    0.3898,...
    0.4046,...
    0.4187,...
    0.4320,...
    0.4453,...
    0.4578,...
    0.4708,...
    0.4820,...
    0.4905,...
    0.5003,...
    0.5102,...
    0.5204,...
    0.5266,...
    0.5322,...
    0.5389,...
    0.5443,...
    0.5471,...
    0.5505,...
    0.5526,...
    0.5522,...
    0.5453,...
    0.5410,...
    0.5354,...
    0.5291,...
    0.5205,...
    0.5130,...
    0.5024,...
    0.4919,...
    0.4825,...
    0.4720,...
    0.4616,...
    0.4489,...
    0.4366,...
    0.4242,...
    0.4111,...
    0.3982,...
    0.3835,...
    0.3711,...
    0.3584,...
    0.3439,...
    0.3316,...
    0.3177,...
    0.3038,...
    0.2910,...
    0.2778,...
    0.2644,...
    0.2497,...
    0.2372,...
    0.2238,...
    0.2105,...
    0.1963,...
    0.1826,...
    0.1685,...
    0.1560,...
    0.1408,...
    0.1263,...
    0.1124,...
    0.0975,...
    0.0821,...
    0.0687,...
    0.0541,...
    0.0399,...
    0.0259,...
    0.0095,...
   -0.0055,...
   -0.0212,...
   -0.0351,...
   -0.0508,...
   -0.0660,...
   -0.0801,...
   -0.0952,...
   -0.1104,...
   -0.1271,...
   -0.1428,...
   -0.1581,...
   -0.1718,...
   -0.1866,...
   -0.2009,...
   -0.2154,...
   -0.2305,...
   -0.2460,...
   -0.2599,...
   -0.2744,...
   -0.2901,...
   -0.3039,...
   -0.3175,...
   -0.3318,...
   -0.3462,...
   -0.3595,...
   -0.3737,...
   -0.3859,...
   -0.3984,...
   -0.4120,...
   -0.4235,...
   -0.4337,...
   -0.4451,...
   -0.4536,...
   -0.4625,...
   -0.4717,...
   -0.4789,...
   -0.4854,...
   -0.4919,...
   -0.4965,...
   -0.5023,...
   -0.5055,...
   -0.5093,...
   -0.5126,...
   -0.5148,...
   -0.5157,...
   -0.5122,...
   -0.5109,...
   -0.5066,...
   -0.5024,...
   -0.4969,...
   -0.4907,...
   -0.4854,...
   -0.4786,...
   -0.4688,...
   -0.4615,...
   -0.4545,...
   -0.4465,...
   -0.4371,...
   -0.4263,...
   -0.4176,...
   -0.4071,...
   -0.3961,...
   -0.3858,...
   -0.3745,...
   -0.3636,...
   -0.3518,...
   -0.3409,...
   -0.3291,...
   -0.3173,...
   -0.3052,...
   -0.2937,...
   -0.2805,...
   -0.2688,...
   -0.2571,...
   -0.2432,...
   -0.2301,...
   -0.2178,...
   -0.2044,...
   -0.1910,...
   -0.1774,...
   -0.1641,...
   -0.1496,...
   -0.1352,...
   -0.1210,...
   -0.1067,...
   -0.0924,...
   -0.0776,...
   -0.0636,...
   -0.0488,...
   -0.0349,...
   -0.0192,...
   -0.0055,...
    0.0094,...
    0.0243,...
    0.0399,...
    0.0551,...
    0.0700,...
    0.0859,...
    0.1013,...
    0.1160,...
    0.1311,...
    0.1461,...
    0.1622,...
    0.1751,...
    0.1895,...
    0.2069,...
    0.2222,...
    0.2364,...
    0.2522,...
    0.2687,...
    0.2841,...
    0.2986,...
    0.3120,...
    0.3262,...
    0.3405,...
    0.3539,...
    0.3695,...
    0.3830,...
    0.3973,...
    0.4100,...
    0.4223,...
    0.4338,...
    0.4462,...
    0.4557,...
    0.4675,...
    0.4769,...
    0.4867,...
    0.4968,...
    0.5046,...
    0.5103,...
    0.5190,...
    0.5246,...
    0.5303,...
    0.5347,...
    0.5390,...
    0.5405,...
    0.5390,...
    0.5366,...
    0.5311,...
    0.5262,...
    0.5216,...
    0.5166,...
    0.5082,...
    0.5001,...
    0.4920,...
    0.4839,...
    0.4743,...
    0.4638,...
    0.4553,...
    0.4440,...
    0.4324,...
    0.4215,...
    0.4087,...
    0.3969,...
    0.3855,...
    0.3723,...
    0.3604,...
    0.3495,...
    0.3362,...
    0.3237,...
    0.3094,...
    0.2966,...
    0.2836,...
    0.2689,...
    0.2550];
  %%
model = interp1([-0.5; pha360; 360.5],[cmdAv(end) cmdAv cmdAv(1)]',Phase.data);
modelOut = zeros(size(model));

NSPINS = 9; spinRate = 3.1; %rpm
nsPerSpin = 60/spinRate*1e9;
t0 = 0; aPrev = []; nGap = 0;
while t0 < epochTmp(end)
  tEnd = t0 + NSPINS*nsPerSpin;
  idx = epochTmp>=t0 & epochTmp<tEnd;
  mTmp = model(idx);  dTmp = cmdRes(idx);
  %XXX TODO: remove sweep data
  idxOk = ~isnan(dTmp);
  if sum(idxOk)< sampleRate*ceil(NSPINS/2)*60/spinRate
    nGap = nGap + 1;
    if nGap > fix(NSPINS/2), aPrev= []; t0 = t0 + 60/spinRate*1e9; continue
    else a = aPrev;% use prev model
    end
  else
    a = mTmp(idxOk)\dTmp(idxOk);
    nGap = 0;
  end
  if ~isempty(aPrev), idxCorr = epochTmp>=t0+fix(NSPINS/2)*nsPerSpin & epochTmp<t0+ceil(NSPINS/2)*nsPerSpin;
  else idxCorr = epochTmp>=t0 & epochTmp<t0+ceil(NSPINS/2)*nsPerSpin; % first points
  end
  modelOut(idxCorr) = model(idxCorr)*a;
  aPrev = a;
  t0 = t0 + 60/spinRate*1e9;
end

end