MMS_CONST = mms_constants; sampleRate = 32;
yymm = '2016/02';
%%
dataDir = ['/data/mms/mms4/edp/fast/l2a/dce2d/' yymm '/'];
fList=dir([dataDir '*.cdf']);

%Model = [];
for i=1:length(fList)
  fName = fList(i).name; dS = fName(25:38);
  dobj = dataobj([dataDir fName]);
  dobjScp = dataobj(['/data/mms/mms4/edp/fast/l2/scpot/' yymm '/mms4_edp_fast_l2_scpot_' dS '_v*.cdf']); 
  tt_ns = dobj.data.mms4_edp_epoch_fast_l2a.data;
  t0 = EpochTT(tt_ns(1)); tStop = EpochTT(tt_ns(end));
  while true
    disp(t0.toUtc)
    tEnd = t0 + 3600;
    if tStop+1800 < tEnd, break, end
    idx = tt_ns>=t0.ttns & tt_ns<tEnd.ttns;
    if sum(idx)> 1800*sampleRate
      Dce.time = dobj.data.mms4_edp_epoch_fast_l2a.data(idx);
      Dce.e12.data = dobj.data.mms4_edp_dce_fast_l2a.data(idx,1);
      Dce.e34.data = dobj.data.mms4_edp_dce_fast_l2a.data(idx,2);
      Dce.e12.bitmask = dobj.data.mms4_edp_bitmask_fast_l2a.data(idx,1);
      Dce.e34.bitmask = dobj.data.mms4_edp_bitmask_fast_l2a.data(idx,2);
      Phase.data = dobj.data.mms4_edp_phase_fast_l2a.data(idx);
      
      Dcv.time = dobjScp.data.mms4_edp_epoch_fast_l2.data(idx);
      for p=1:4
        pS = sprintf('v%d',p);
        Dcv.(pS).data = dobjScp.data.mms4_edp_dcv_fast_l2.data(idx,p);
        Dcv.(pS).bitmask = dobjScp.data.mms4_edp_bitmask_fast_l2.data(idx);
      end
      
      [~,Model360] = mms_sdp_model_spin_residual(Dce,Dcv,Phase,...
        {'e12','e34','v1','v2','v3','v4'},sampleRate);
      Model360.time = irf.tint(t0,tEnd);
      Model360.aspoc = any(bitand(Dce.e12.bitmask,...
        MMS_CONST.Bitmask.ASPOC_RUNNING));
      Model360.psp = median(dobjScp.data.mms4_edp_psp_fast_l2.data(idx));
      Model = [Model Model360]; clear Model360
    end
    t0 = tEnd;
  end
end

%% 
Model360.e12 = zeros(360,length(Model));
for i=1:length(Model)
  Model360.e12(:,i) = Model(i).e12;
end
%% 
for sig = {'e12','e34','v1','v2','v3','v4'}
  pS = sig{:};
  Model360.(pS) = zeros(360,length(Model));
  for i=1:length(Model)
    Model360.(pS)(:,i) = Model(i).(pS);
  end
end
%% 
Model360.t = zeros(length(Model),1);
Model360.psp  = zeros(length(Model),1);
Model360.aspoc = zeros(length(Model),1);
for i=1:length(Model)
  Model360.t(i) = Model(i).time.start.epochUnix+1800;
  Model360.psp(i) = Model(i).psp;
  Model360.aspoc(i) = Model(i).aspoc;
end
%%
e12=sum(abs(Model360.e12))';
e34=sum(abs(Model360.e34))';
idxA = logical((Model360.aspoc)); t = Model360.t;

h=irf_figure(3);
hca = irf_panel('e12');
irf_plot(hca,{[t e12],[t(~idxA) e12(~idxA)],[t(idxA) e12(idxA)]},'comp','linestyle',{'-','*','x'})
ylabel(hca,'sum(abs(R)) 12')
title(hca,upper(mmsId))
  
hca = irf_panel('e34');
irf_plot(hca,{[t e34],[t(~idxA) e34(~idxA)],[t(idxA) e34(idxA)]},'comp','linestyle',{'-','*','x'})
ylabel(hca,'sum(abs(R)) 34')

hca = irf_panel('psp');
irf_plot(hca,[t Model360.psp])
ylabel(hca,'P2ScPot [V]')
irf_print_fig([mmsId '_EResLinePlot_Dec_Feb'],'png')

%%
e12=abs(fft(Model360.e12))';
e34=abs(fft(Model360.e34))';
idxA = logical((Model360.aspoc)); t = Model360.t;
comps = [2 4 6 8 10 12];

h=irf_figure(3);
hca = irf_panel('e12');
irf_plot(hca,[t e12(:,comps)])
ylabel(hca,'abs(fft(R)) 12'), legend(hca,{'2','4','6','8','10','12'})
title(hca,upper(mmsId))
  
hca = irf_panel('e34');
irf_plot(hca,[t e34(:,comps)])
ylabel(hca,'abs(fft(R)) 34'), legend(hca,{'2','4','6','8','10','12'})

hca = irf_panel('psp');
irf_plot(hca,[t Model360.psp])
ylabel(hca,'P2ScPot [V]')
irf_print_fig([mmsId '_EResHarmPlot_Dec_Feb'],'png')


%%
mmsId = 'mms4';
idxChk = 821; %212; %;670; %268;
plot(Model(idxChk).e12)
hold on
plot(Model(idxChk).e34)
set(gca,'XTick',0:30:360,'Xlim',[0 360])
grid on
ylabel('residual [mV/m]'), xlabel('phase [deg]')
title([upper(mmsId) ' ' irf_fname(Model(268).time,2)],'Interpreter','none')
legend('12','34')
irf_print_fig([mmsId '_ResLinePlot_' irf_fname(Model(idxChk).time,2)],'png')

%% phase plot
modelTmp = [];
for signal = {'e12','e34'}
  modelTmp = [modelTmp Model(idxChk).(signal{:})]; %#ok<AGROW>
end
phaseplot((1:360)-0.5,modelTmp)
title(gca,[upper(mmsId) ' ' irf_fname(Model(268).time,2)],'Interpreter','none')
irf_print_fig([mmsId '_sdp_spinresE_pha_' irf_fname(Model(idxChk).time,2)],'png')

%% CMD
cmd = (Model360.v3 - 0.5*(Model360.v1+Model360.v2))/.120/2;
