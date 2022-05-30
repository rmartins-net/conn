function [Z,W,xyz]=conn_vv2rr(ROI,varargin)
% computes ROI-to-ROI matrix by averaging Voxel-to-Voxel correlations
% 

% note: call from within conn_process or conn_batch

global CONN_x;

options=struct(...
    'style','vv2rr',...
    'filepath',[],...
    'folderout',[],...
    'validsubjects',[],...
    'contrastsubjects',[],...
    'validconditions',[],...
    'contrastconditions',[]);

for n=1:2:numel(varargin)-1, assert(isfield(options,varargin{n}),'unrecognized option %s',varargin{n}); options.(varargin{n})=varargin{n+1}; end

nconditions=length(CONN_x.Setup.conditions.names)-1;
if isempty(options.style), style='vv2rr'; end
if isempty(options.filepath), options.filepath=CONN_x.folders.preprocessing; end
if isempty(options.validsubjects), options.validsubjects=1:CONN_x.Setup.nsubjects; end
if isempty(options.contrastsubjects), options.contrastsubjects=ones(1,numel(options.validsubjects))/numel(options.validsubjects); end
if isempty(options.validconditions), options.validconditions=1:nconditions; end
if isempty(options.contrastconditions), options.contrastconditions=ones(1,numel(options.validconditions))/numel(options.validconditions); end

icondition=[];isnewcondition=[];for ncondition=1:nconditions,[icondition(ncondition),isnewcondition(ncondition)]=conn_conditionnames(CONN_x.Setup.conditions.names{ncondition}); end
if any(isnewcondition(options.validconditions)), error(['Some conditions have not been processed yet. Re-run previous step']); end
% addnew=false;
if iscell(ROI), ROI=char(ROI); end
if ischar(ROI), ROI=conn_fileutils('spm_vol',ROI); end

%h=conn_waitbar(0,'Extracting correlation matrix, please wait...');
lastmatdim=[];
Z=[];
xyz=[];
for ivalidcondition=1:numel(options.validconditions),
    ncondition=options.validconditions(ivalidcondition);
    for ivalidsubject=1:numel(options.validsubjects)
        nsub=options.validsubjects(ivalidsubject);
        filename_B1=fullfile(options.filepath,['vvPC_Subject',num2str(nsub,'%03d'),'_Condition',num2str(icondition(ncondition),'%03d'),'.mat']);
        Y1=conn_vol(filename_B1);
        if isequal(lastmatdim, Y1.matdim)
        else
            if isstruct(ROI), % 4d-file
                xyz=conn_convertcoordinates('idx2tal',1:prod(Y1.matdim.dim),Y1.matdim.mat,Y1.matdim.dim)';
                W=conn_fileutils('spm_get_data',ROI,pinv(ROI(1).mat)*xyz);
                if size(W,1)==1&&isequal(reshape(unique(W),[],1),(0:max(W(:)))'), W=double(repmat(W,[max(W(:)),1])==repmat((1:max(W(:)))',[1,size(W,2)])); end
                w=W(:,Y1.voxels);
                sw=sum(w,2);
                temp=w*xyz(1:3,Y1.voxels)';
                xyz=temp./repmat(max(eps,sw),1,3);
                lastmatdim=Y1.matdim;
            else W=ROI; % ROIs-by-voxels matrix
            end
            assert(prod(Y1.matdim.dim)==size(W,2),'unequal number of voxels in ROI (%d) and VV (%d) files',size(W,2), prod(Y1.matdim.dim));
        end
        x=conn_get_volume(Y1);
        w=W(:,Y1.voxels);
        sw=sum(w,2);
        switch(options.style)
            case 'vv2rr'
                if isempty(Z), Z=zeros(size(W,1),size(W,1)); end
                temp=x*w';
                Z=Z+options.contrastsubjects(ivalidsubject)*options.contrastconditions(ivalidcondition)*(temp'*temp)./max(eps,sw*sw');
            case 'vv2rv'
                if isempty(Z), Z=zeros([size(W,1),Y1.matdim.dim]); end
                temp=x*w';
                Z(:,Y1.voxels)=Z(:,Y1.voxels)+options.contrastsubjects(ivalidsubject)*options.contrastconditions(ivalidcondition)*(diag(1./sw)*temp'*x);
            otherwise
                error('unrecognized style %s (vv2rr or vv2rv options only)',options.style);
        end
        %conn_waitbar(((ivalidcondition-1)*CONN_x.Setup.nsubjects+nsub)/numel(options.validconditions)/CONN_x.Setup.nsubjects,h,sprintf('Subject %d Condition %d',nsub,ncondition));
        %n=n+1;
    end
%     if ~isempty(folderout)
%         filename=fullfile(folderout,['resultsROI_Condition',num2str(icondition(ncondition),'%03d'),'.mat']);
%         save(filename,'Z','names','names2','xyz'); %%%
%     end
end
%conn_waitbar('close',h);
% if addnew %%%
%     if ~isfield(CONN_x,'Analyses')||isempty(CONN_x.Analyses), tianalysis=1;
%     else tianalysis=numel(CONN_x.Analyses)+1;
%     end
%     CONN_x.Analyses(tianalysis).name=foldername;
%     CONN_x.Analysis=tianalysis;
%     if 1
%         CONN_x.Analyses(tianalysis).sourcenames={};
%         CONN_x.Analyses(tianalysis).sources=names;
%         CONN_x.Analyses(tianalysis).type=1;
%         conn save;
%         conn_msgbox({'ROI-to-ROI analyses created',['Go to ''second-level Results''-''>ROI-to-ROI'' and select analysis ',foldername]},'post-hoc analyses');
%     end
% end


end