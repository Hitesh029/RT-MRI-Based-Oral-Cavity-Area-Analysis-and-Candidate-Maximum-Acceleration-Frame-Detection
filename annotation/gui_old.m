function varargout = gui(varargin)
%GUI M-file for gui.fig
%      GUI, by itself, creates a new GUI or raises the existing
%      singleton*.
%
%      H = GUI returns the handle to a new GUI or the handle to
%      the existing singleton*.
%
%      GUI('Property','Value',...) creates a new GUI using the
%      giv
% en property value pairs. Unrecognized properties are passed via
%      varargin to gui_OpeningFcn.  This calling syntax produces a
%      warning when there is an existing ,singleton*.
%
%      GUI('CALLBACK') and GUI('CALLBACK',hObject,...) call the

%      local function named CALLBACK in GUI.M with the given input
%      arguments.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".    
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help gui

% Last Modified by GUIDE v2.5 20-May-2014 15:46:27

% Begin initialization code - DO NOT EDIT

gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @gui_OpeningFcn, ...
                   'gui_OutputFcn',  @gui_OutputFcn, ...
                   'gui_LayoutFcn',  [], ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
   gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before gui is made visible.
function gui_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   unrecognized PropertyName/PropertyValue pairs from the
%            command line (see VARARGIN)

% Choose default command line output for gui
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);


% UIWAIT makes gui wait for user response (see UIRESUME)
% uiwait(handles.figure1);




% --- Outputs from this function are returned to the command line.
function varargout = gui_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;

% % % 
% % % % --- Executes on button press in pushbutton1.
% % % function pushbutton1_Callback(hObject, eventdata, handles) %Next
% % % % hObject    handle to pushbutton1 (see GCBO)
% % % % eventdata  reserved - to be defined in a future version of MATLAB
% % % % handles    structure with handles and user data (see GUIDATA)
% % % disp('Push1');
% % % button_state = get(hObject,'Value');
% % % if ~isfield(handles,'SUBJ')
% % %     uiwait(msgbox('First choose a subject.','Title','modal'));
% % %     return;
% % % end
% % % if handles.framecount <= size(handles.imgs,2)
% % %     dir([handles.DIR_phoneme_annotation handles.phoneme_files(handles.thisPhoneme_file).name])
% % %     while ~isempty(dir([handles.DIR_phoneme_annotation handles.phoneme_files(handles.thisPhoneme_file).name]))
% % %         handles.thisPhoneme_file=handles.thisPhoneme_file+1;guidata(hObject,handles);
% % %     end
% % %     
% % %     if isempty(dir([handles.DIR_phoneme_annotation handles.phoneme_files(handles.thisPhoneme_file).name]))
% % % %         handles
% % %         disp(['Showing ' handles.DIR_phoneme_lab handles.phoneme_files(handles.thisPhoneme_file).name]);
% % %         load([handles.DIR_phoneme_lab handles.phoneme_files(handles.thisPhoneme_file).name]);
% % %         
% % %         handles.curr_frame=required_frame;guidata(hObject,handles);
% % %         imshow(required_frame, 'Parent', handles.axes3);hold(handles.axes3,'on');
% % %         
% % %         
% % %         title_temp = handles.phoneme_files(handles.thisPhoneme_file).name;
% % %         under_scores = find(title_temp=='_');
% % %         title_temp(under_scores)=' ';
% % %         title_temp=title_temp(1:end-4);%title_temp(under_scores(2)+1:under_scores(5)-1);
% % %         handles.title_temp=title_temp;guidata(hObject,handles);
% % %         title(title_temp);
% % %              
% % %         disp('incre');
% % %     end
% % %     disp('increment');
% % %     handles.thisPhoneme_file=handles.thisPhoneme_file+1;guidata(hObject,handles);
% % % else
% % %     uiwait(msgbox('All of the chosen phonemes is over.','Title','modal'));
% % % end


% --- Executes on button press in pushbutton5.
function pushbutton5_Callback(hObject, eventdata, handles) 
%% Save all and continue
% hObject    handle to pushbutton5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
disp('Push5');
if length(handles.UL)<2 || length(handles.LL)<2 || length(handles.AVR)<2 || length(handles.GLTB)<2 || length(handles.VEL)<2
    uiwait(msgbox('Please finish the additional five point markers - UL, LL, AVR, GLTB, VEL','Title','modal'));
    return;
else
    contour1=handles.contours.contour1;
    contour1_marks=handles.contours.contour1_marks;
    contour2=handles.contours.contour2;
    contour2_marks=handles.contours.contour2_marks;
    contour3=handles.contours.contour3;
    contour3_marks=handles.contours.contour3_marks;
    UL=handles.UL;LL=handles.LL;AVR=handles.AVR;VEL=handles.VEL;GLTB=handles.GLTB;
    hold(handles.axes3,'off');
    imagesc(reshape(handles.imgs(handles.randind(handles.framecount),:),68,68),'Parent',handles.axes3);hold(handles.axes3,'on');colormap gray
    set(handles.axes3,'xticklabel',[]);set(handles.axes3,'yticklabel',[]);
    plot(contour1(:,1),contour1(:,2),'r-');
    plot(contour2(:,1),contour2(:,2),'-');
    plot(contour3(:,1),contour3(:,2),'g-');
    MARKERSIZE=30;
    plot(UL(1),UL(2),'c.','markersize',MARKERSIZE, 'Parent', handles.axes3);
    plot(LL(1),LL(2),'c.','markersize',MARKERSIZE, 'Parent', handles.axes3);
    plot(AVR(1),AVR(2),'c.','markersize',MARKERSIZE, 'Parent', handles.axes3);
    plot(GLTB(1),GLTB(2),'c.','markersize',MARKERSIZE, 'Parent', handles.axes3);
    plot(VEL(1),VEL(2),'c.','markersize',MARKERSIZE, 'Parent', handles.axes3);
    title([handles.allfiles(handles.filecount).name ' - ' num2str(handles.randind(handles.framecount)) '(' num2str(handles.framecount) ' out of ' num2str(size(handles.imgs,1)) ')']);
    user_ip=questdlg('Do you want to save finally?','Warning','Ok','Cancel','Ignore');
    disp('yes/no');
    if strcmp(user_ip,'Ok')
        i=handles.randind(handles.framecount); 
        handles.annotation(i).contour1=contour1;
        handles.annotation(i).contour2=contour2;
        handles.annotation(i).contour3=contour3;
        handles.annotation(i).UL=UL;handles.annotation(i).LL=LL;handles.annotation(i).AVR=AVR;handles.annotation(i).VEL=VEL;handles.annotation(i).GLTB=GLTB;
        
            
        imgs=handles.imgs;
        randind=handles.randind;
        framecount=handles.framecount;
        annotation=handles.annotation;
        current_file=handles.allfiles(handles.filecount).name;
        save([handles.DIR_annotation current_file(1:end-4) '_temp.mat'],'imgs','randind','framecount','annotation');
        handles.running_contours=handles.fixed_contours;
        
        if framecount==size(imgs,1)
            disp('equal');
            save([handles.DIR_annotation current_file(1:end-3) 'mat'],'annotation');
            
            handles.filecount=handles.filecount+1;
            
            if handles.filecount>length(handles.allfiles)
                uiwait(msgbox('All videos of the chosen subject are already annotated','Title','modal'));
                return;
            end
            
            current_file=handles.allfiles(handles.filecount).name;
            disp(current_file);
            %%% may have to change this depending on matlab version
%             mov=aviread([handles.DIR_videos current_file]);
            vidReader=VideoReader([handles.DIR_videos current_file]);
            vidFrames = read(vidReader);
            %%% may have to change this depending on matlab version
            imgs=zeros(size(vidFrames,4),68*68);    %Shreya
            annotation=[];
%             for i=1:length(mov)
            for i=1:size(vidFrames,4)
%                 dt=mov(i).cdata;
                dt=vidFrames(:,:,:,i);
                dt=double(rgb2gray(dt));
                imgs(i,:)=reshape(dt,1,68*68);    %Shreya
                annotation(i).contour1=[];
                annotation(i).contour2=[];
                annotation(i).contour3=[];
                annotation(i).UL=[];annotation(i).LL=[];annotation(i).AVR=[];annotation(i).VEL=[];annotation(i).GLTB=[];
            end
            handles.annotation=annotation;
            handles.imgs=imgs;
%             randind=randperm(length(mov));
            randind=randperm(size(vidFrames,4));
            handles.randind=randind;
            framecount=1;
            handles.framecount=framecount;
            handles.UL=-1;handles.LL=-1;handles.AVR=-1;handles.VEL=-1;handles.GLTB=-1;
            save([handles.DIR_annotation current_file(1:end-4) '_temp.mat'],'imgs','randind','framecount','annotation');
            
            
        else
            
            handles.framecount=handles.framecount+1;
            handles.UL=-1;handles.LL=-1;handles.AVR=-1;handles.VEL=-1;handles.GLTB=-1;
            
        end
        
        hold(handles.axes3,'off');
        imagesc(reshape(handles.imgs(handles.randind(handles.framecount),:),68,68), 'Parent', handles.axes3);hold(handles.axes3,'on');colormap gray;
        title([handles.allfiles(handles.filecount).name ' - ' num2str(handles.randind(handles.framecount)) '(' num2str(handles.framecount) ' out of ' num2str(size(handles.imgs,1)) ')']);
        set(handles.axes3,'xticklabel',[]);set(handles.axes3,'yticklabel',[]);
        

    end
end
guidata(hObject, handles);



% --- Executes on button press in pushbutton7.
function pushbutton7_Callback(hObject, eventdata, handles) %Done
% hObject    handle to pushbutton7 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
disp('Push7');

t_cont = handles.draw_h.Position;
switch handles.selected_contour
    case 'Contour1(RED)'
        temp_contour=handles.ref_contours.contour1;
        temp_contour_marks=handles.ref_contours.contour1_marks;
        handles.contours.contour1=[temp_contour(1:temp_contour_marks(1),:);t_cont;temp_contour(temp_contour_marks(2):end,:)];
         guidata(hObject,handles);
         handles.running_contours.contour1=handles.contours.contour1;
         guidata(hObject,handles);
        temp=handles.contours.contour1;
        hold(handles.axes3,'off');
        imagesc(reshape(handles.imgs(handles.randind(handles.framecount),:),68,68),'Parent',handles.axes3);hold(handles.axes3,'on');colormap gray
        set(handles.axes3,'xticklabel',[]);set(handles.axes3,'yticklabel',[]);
        plot(temp(:,1),temp(:,2),'r*-');
        title([handles.allfiles(handles.filecount).name ' - ' num2str(handles.randind(handles.framecount)) '(' num2str(handles.framecount) ' out of ' num2str(size(handles.imgs,1)) ')']);
        handles.C1Lock=0;guidata(hObject,handles);
        handles.C2Lock=0;guidata(hObject,handles);
        handles.C3Lock=0;guidata(hObject,handles);
        handles.UL=-1;
        handles.VEL=-1;guidata(hObject,handles);
        
    case 'Contour2(BLUE)'
        temp_contour=handles.ref_contours.contour2;
        temp_contour_marks=handles.ref_contours.contour2_marks;
        handles.contours.contour2=[temp_contour(1:[],:);t_cont;temp_contour([]:end,:)];
         guidata(hObject,handles);
         handles.running_contours.contour2=handles.contours.contour2;
         guidata(hObject,handles);
        temp=handles.contours.contour2;
        hold(handles.axes3,'off');
        imagesc(reshape(handles.imgs(handles.randind(handles.framecount),:),68,68),'Parent',handles.axes3);hold(handles.axes3,'on');colormap gray
        set(handles.axes3,'xticklabel',[]);set(handles.axes3,'yticklabel',[]);
        plot(temp(:,1),temp(:,2),'*-');
        title([handles.allfiles(handles.filecount).name ' - ' num2str(handles.randind(handles.framecount)) '(' num2str(handles.framecount) ' out of ' num2str(size(handles.imgs,1)) ')']);
        handles.C1Lock=0;guidata(hObject,handles);
        handles.C2Lock=0;guidata(hObject,handles);
        handles.C3Lock=0;guidata(hObject,handles);
        handles.LL=-1;
        handles.AVR=-1;guidata(hObject,handles);
        
    case 'Contour3(GREEN)'
        temp_contour=handles.ref_contours.contour3;
        temp_contour_marks=handles.ref_contours.contour3_marks;
        handles.contours.contour3=[temp_contour(1:temp_contour_marks(1),:);t_cont;temp_contour(temp_contour_marks(2):end,:)];
         guidata(hObject,handles);
         handles.running_contours.contour3=handles.contours.contour3;
         guidata(hObject,handles);
        temp=handles.contours.contour3;
        hold(handles.axes3,'off');
        imagesc(reshape(handles.imgs(handles.randind(handles.framecount),:),68,68),'Parent',handles.axes3);hold(handles.axes3,'on');colormap gray
        set(handles.axes3,'xticklabel',[]);set(handles.axes3,'yticklabel',[]);
        plot(temp(:,1),temp(:,2),'g*-');
        title([handles.allfiles(handles.filecount).name ' - ' num2str(handles.randind(handles.framecount)) '(' num2str(handles.framecount) ' out of ' num2str(size(handles.imgs,1)) ')']);
        handles.C1Lock=0;guidata(hObject,handles);
        handles.C2Lock=0;guidata(hObject,handles);
        handles.C3Lock=0;guidata(hObject,handles);
        handles.GLTB=-1;guidata(hObject,handles);
        
        
end



% --- Executes on selection change in popupmenu3.
function popupmenu3_Callback(hObject, eventdata, handles) %subject popup
% hObject    handle to popupmenu3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
%disp('Pop3');
% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu3 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu3
all_contents = get(hObject,'String');
cnt = get(hObject,'value');
handles.SUBJ = all_contents{cnt};
handles.SUBJTemplateFIle=['templates/' handles.SUBJ '_template.mat'];
handles.SUBJTemplateImageFIle=['templates/' handles.SUBJ '_template_image.mat'];
contours=load(handles.SUBJTemplateFIle);handles.contours=contours;
handles.ref_contours=contours;

temp_contour=handles.ref_contours.contour1;
temp_contour_marks=handles.ref_contours.contour1_marks;
handles.fixed_contours.contour1=[temp_contour(1:temp_contour_marks(1),:);temp_contour(temp_contour_marks(2):end,:)];guidata(hObject,handles);
temp_contour=handles.ref_contours.contour2;
handles.ref_contours.contour2_marks=[];
handles.fixed_contours.contour2=[temp_contour(1:[],:);temp_contour([]:end,:)];guidata(hObject,handles);
temp_contour=handles.ref_contours.contour3;
temp_contour_marks=handles.ref_contours.contour3_marks;
handles.fixed_contours.contour3=[temp_contour(1:temp_contour_marks(1),:);temp_contour(temp_contour_marks(2):end,:)];guidata(hObject,handles);

handles.running_contours=handles.fixed_contours;

imageframe=load(handles.SUBJTemplateImageFIle);handles.imageframe=imageframe;
imagesc(imageframe.required_frame, 'Parent', handles.axes2);colormap(gray);hold(handles.axes2,'on');
set(handles.axes2,'xticklabel',[]);set(handles.axes2,'yticklabel',[]);
plot(contours.contour1(:,1),contours.contour1(:,2),'r*-', 'Parent', handles.axes2);
plot(contours.contour2(:,1),contours.contour2(:,2),'*-', 'Parent', handles.axes2);
plot(contours.contour3(:,1),contours.contour3(:,2),'g*-', 'Parent', handles.axes2);
MARKERSIZE=30;
pt=contours.ULpt;X=contours.contour1(pt,1);Y=contours.contour1(pt,2);plot(X,Y,'c.','markersize',MARKERSIZE, 'Parent', handles.axes2);
text(X-6,Y,'UL','fontsize',16,'color',[1 0 0], 'Parent', handles.axes2);
pt=contours.VELpt;X=contours.contour1(pt,1);Y=contours.contour1(pt,2);plot(X,Y,'c.','markersize',MARKERSIZE, 'Parent', handles.axes2);
text(X+2,Y+2,'VEL','fontsize',16,'color',[1 0 0], 'Parent', handles.axes2);
pt=contours.LLpt;X=contours.contour2(pt,1);Y=contours.contour2(pt,2);plot(X,Y,'c.','markersize',MARKERSIZE, 'Parent', handles.axes2);
text(X-6,Y,'LL','fontsize',16,'color',[1 0 0], 'Parent', handles.axes2);
pt=contours.AVRpt;X=contours.contour2(pt,1);Y=contours.contour2(pt,2);plot(X,Y,'c.','markersize',MARKERSIZE, 'Parent', handles.axes2);
text(X+2,Y+2,'AVR','fontsize',16,'color',[1 0 0], 'Parent', handles.axes2);
pt=contours.GLTBpt;X=contours.contour3(pt,1);Y=contours.contour3(pt,2);plot(X,Y,'c.','markersize',MARKERSIZE, 'Parent', handles.axes2);
text(X+2,Y+2,'GLT\_B','fontsize',16,'color',[1 0 0], 'Parent', handles.axes2);

handles.DIR_videos=['videos/' handles.SUBJ '/'];
handles.DIR_annotation=['annotation/' handles.SUBJ '/'];
handles.C1Lock=0;
handles.C2Lock=0;
handles.C3Lock=0;


handles.UL=-1;
handles.LL=-1;
handles.AVR=-1;
handles.GLTB=-1;
handles.VEL=-1;

handles.allfiles = dir([handles.DIR_videos '*.avi']);

if isempty(handles.allfiles)
    uiwait(msgbox( ...
        ['No AVI files found in: ' handles.DIR_videos], ...
        'Error', 'modal'));
    return;
end

cnt = 1;

while cnt <= length(handles.allfiles)

    temp = handles.allfiles(cnt).name;

    finalFile = [handles.DIR_annotation temp(1:end-3) 'mat'];

    if isempty(dir(finalFile))
        break;
    end

    cnt = cnt + 1;
end

% Check whether every video is already annotated
if cnt > length(handles.allfiles)

    uiwait(msgbox( ...
        ['All videos of subject ' handles.SUBJ ...
        ' are already annotated.'], ...
        'Information', 'modal'));

    return;
end

handles.filecount = cnt;
current_file = handles.allfiles(cnt).name;
if isempty(dir([handles.DIR_annotation current_file(1:end-4) '_temp.mat']))
    %%% may have to change this depending on matlab version
    %             mov=aviread([handles.DIR_videos current_file]);
    vidReader=VideoReader([handles.DIR_videos current_file]);
    vidFrames = read(vidReader);
    disp(vidFrames);
    %%% may have to change this depending on matlab version
    imgs=zeros(size(vidFrames,4),68*68);   %Shreya
    annotation=[];
    %             for i=1:length(mov)
    for i=1:size(vidFrames,4)
        %                 dt=mov(i).cdata;
        dt=vidFrames(:,:,:,i);
        dt=double(rgb2gray(dt));
        imgs(i,:)=reshape(dt,1,68*68);   %Shreya asked to change
        annotation(i).contour1=[];
        annotation(i).contour2=[];
        annotation(i).contour3=[];
        annotation(i).UL=[];annotation(i).LL=[];annotation(i).AVR=[];annotation(i).VEL=[];annotation(i).GLTB=[];
    end
    handles.annotation=annotation;
    handles.imgs=imgs;
    %             randind=randperm(length(mov));
    randind=randperm(size(vidFrames,4));
    handles.randind=randind;
    framecount=1;
    handles.framecount=framecount;
    save([handles.DIR_annotation current_file(1:end-4) '_temp.mat'],'imgs','randind','framecount','annotation');
    
else
    load([handles.DIR_annotation current_file(1:end-4) '_temp.mat']);
    handles.imgs=imgs;
    handles.randind=randind;
    handles.framecount=framecount+1;
    handles.annotation=annotation;
end
imagesc(reshape(handles.imgs(handles.randind(handles.framecount),:),68,68), 'Parent', handles.axes3);hold(handles.axes3,'on');colormap gray;
title([handles.allfiles(handles.filecount).name ' - ' num2str(handles.randind(handles.framecount)) '(' num2str(handles.framecount) ' out of ' num2str(size(handles.imgs,1)) ')']);
set(handles.axes3,'xticklabel',[]);set(handles.axes3,'yticklabel',[]);


guidata(hObject,handles);

% --- Executes during object creation, after setting all properties.
function popupmenu3_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
%disp('Pop3C');


% --- Executes on selection change in popupmenu4.
function popupmenu4_Callback(hObject, eventdata, handles) %Contour popup
% hObject    handle to popupmenu4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
%disp('Pop4');
% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu4 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu4
all_contents = get(hObject,'String');
selected_content = get(hObject,'Value');

switch all_contents{selected_content}
    case 'Contour1(RED)'
        %handles.C1Lock;
        if ~handles.C2Lock && ~handles.C3Lock
        hold(handles.axes3,'off');
        temp_contour=handles.ref_contours.contour1;
        
        
%         temp_contour_marks=handles.ref_contours.contour1_marks;
        imagesc(reshape(handles.imgs(handles.randind(handles.framecount),:),68,68),'Parent',handles.axes3);hold(handles.axes3,'on');colormap gray
        set(handles.axes3,'xticklabel',[]);set(handles.axes3,'yticklabel',[]);
%         plot(temp_contour(:,1),temp_contour(:,2),'r*');
        temp_fixed_contour=handles.fixed_contours.contour1;plot(temp_fixed_contour(:,1),temp_fixed_contour(:,2),'r*');
        temp_fixed_contour=handles.fixed_contours.contour2;plot(temp_fixed_contour(:,1),temp_fixed_contour(:,2),'*');
        temp_fixed_contour=handles.fixed_contours.contour3;plot(temp_fixed_contour(:,1),temp_fixed_contour(:,2),'g*');
        
        temp_running_contour=handles.running_contours.contour2;plot(temp_running_contour(:,1),temp_running_contour(:,2),'*');
        temp_running_contour=handles.running_contours.contour3;plot(temp_running_contour(:,1),temp_running_contour(:,2),'g*');
        
        
%         plot(temp_contour(1:temp_contour_marks(1),1),temp_contour(1:temp_contour_marks(1),2),'r*-');
%         plot(temp_contour(temp_contour_marks(2):end,1),temp_contour(temp_contour_marks(2):end,2),'r*-');
        title([handles.allfiles(handles.filecount).name ' - ' num2str(handles.randind(handles.framecount)) '(' num2str(handles.framecount) ' out of ' num2str(size(handles.imgs,1)) ')']);
        h = drawpolygon;
        handles.draw_h = h;
        handles.imp_h=h; guidata(hObject,handles);
        handles.C1Lock=1;guidata(hObject,handles);
        handles.selected_contour = all_contents{selected_content};
        guidata(hObject,handles);
        end
        
    case 'Contour2(BLUE)'
        %handles.C2Lock
        if ~handles.C1Lock && ~handles.C3Lock
        hold(handles.axes3,'off');
        temp_contour=handles.ref_contours.contour2;
        
%         temp_contour_marks=handles.ref_contours.contour2_marks;
        imagesc(reshape(handles.imgs(handles.randind(handles.framecount),:),68,68),'Parent',handles.axes3);hold(handles.axes3,'on');colormap gray
        set(handles.axes3,'xticklabel',[]);set(handles.axes3,'yticklabel',[]);
%         plot(temp_contour(:,1),temp_contour(:,2),'*');
        temp_fixed_contour=handles.fixed_contours.contour1;plot(temp_fixed_contour(:,1),temp_fixed_contour(:,2),'r*');
        temp_fixed_contour=handles.fixed_contours.contour2;plot(temp_fixed_contour(:,1),temp_fixed_contour(:,2),'*');
        temp_fixed_contour=handles.fixed_contours.contour3;plot(temp_fixed_contour(:,1),temp_fixed_contour(:,2),'g*');
        temp_running_contour=handles.running_contours.contour1;plot(temp_running_contour(:,1),temp_running_contour(:,2),'r*');
        
        temp_running_contour=handles.running_contours.contour3;plot(temp_running_contour(:,1),temp_running_contour(:,2),'g*');
        
%         plot(temp_contour(1:temp_contour_marks(1),1),temp_contour(1:temp_contour_marks(1),2),'*-');
%         plot(temp_contour(temp_contour_marks(2):end,1),temp_contour(temp_contour_marks(2):end,2),'*-');
        title([handles.allfiles(handles.filecount).name ' - ' num2str(handles.randind(handles.framecount)) '(' num2str(handles.framecount) ' out of ' num2str(size(handles.imgs,1)) ')']);
        h = drawpolygon;
        handles.draw_h = h;
        handles.imp_h=h; guidata(hObject,handles);
        handles.C2Lock=1;guidata(hObject,handles);
        handles.selected_contour = all_contents{selected_content};
        guidata(hObject,handles);
        end
        
    case 'Contour3(GREEN)'
        %handles.C3Lock
        if ~handles.C2Lock && ~handles.C1Lock
        hold(handles.axes3,'off');
        temp_contour=handles.ref_contours.contour3;
        
        
%         temp_contour_marks=handles.ref_contours.contour3_marks;
        imagesc(reshape(handles.imgs(handles.randind(handles.framecount),:),68,68),'Parent',handles.axes3);hold(handles.axes3,'on');colormap gray
        set(handles.axes3,'xticklabel',[]);set(handles.axes3,'yticklabel',[]);
%         plot(temp_contour(:,1),temp_contour(:,2),'g*');
        temp_fixed_contour=handles.fixed_contours.contour1;plot(temp_fixed_contour(:,1),temp_fixed_contour(:,2),'r*');
        temp_fixed_contour=handles.fixed_contours.contour2;plot(temp_fixed_contour(:,1),temp_fixed_contour(:,2),'*');
        temp_fixed_contour=handles.fixed_contours.contour3;plot(temp_fixed_contour(:,1),temp_fixed_contour(:,2),'g*');
        temp_running_contour=handles.running_contours.contour1;plot(temp_running_contour(:,1),temp_running_contour(:,2),'r*');
        temp_running_contour=handles.running_contours.contour2;plot(temp_running_contour(:,1),temp_running_contour(:,2),'*');
        
        
%         plot(temp_contour(1:temp_contour_marks(1),1),temp_contour(1:temp_contour_marks(1),2),'g*-');
%         plot(temp_contour(temp_contour_marks(2):end,1),temp_contour(temp_contour_marks(2):end,2),'g*-');
        title([handles.allfiles(handles.filecount).name ' - ' num2str(handles.randind(handles.framecount)) '(' num2str(handles.framecount) ' out of ' num2str(size(handles.imgs,1)) ')']);
        h = drawpolygon;
        handles.draw_h = h;
        handles.imp_h=h; guidata(hObject,handles);
        handles.C3Lock=1;guidata(hObject,handles);
        handles.selected_contour = all_contents{selected_content};
        guidata(hObject,handles);
        end
        
end



% --- Executes during object creation, after setting all properties.
function popupmenu4_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
%disp('Pop4C');


% --- Executes on button press in pushbutton9.
function pushbutton9_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton9 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
hold(handles.axes3,'off');
imagesc(reshape(handles.imgs(handles.randind(handles.framecount),:),68,68),'Parent',handles.axes3);hold(handles.axes3,'on');colormap gray
title([handles.allfiles(handles.filecount).name ' - ' num2str(handles.randind(handles.framecount)) '(' num2str(handles.framecount) ' out of ' num2str(size(handles.imgs,1)) ')']);
set(handles.axes3,'xticklabel',[]);set(handles.axes3,'yticklabel',[]);
contour1=handles.contours.contour1;
contour2=handles.contours.contour2;
contour3=handles.contours.contour3;

if isempty(contour1)
    uiwait(msgbox('First finish drawing contour1(RED)','Title','modal'));
    return
end

[x y]=ginput(1);

plot(contour1(:,1),contour1(:,2),'r*-');
plot(contour2(:,1),contour2(:,2),'*-');
plot(contour3(:,1),contour3(:,2),'g*-');
ind=dsearchn(contour1,[x y]);
x=contour1(ind,1);y=contour1(ind,2);

handles.UL=[x y];guidata(hObject,handles);
plot(x,y,'c.','markersize',22);

% --- Executes on button press in pushbutton10.
function pushbutton10_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton10 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
hold(handles.axes3,'off');
imagesc(reshape(handles.imgs(handles.randind(handles.framecount),:),68,68),'Parent',handles.axes3);hold(handles.axes3,'on');colormap gray
title([handles.allfiles(handles.filecount).name ' - ' num2str(handles.randind(handles.framecount)) '(' num2str(handles.framecount) ' out of ' num2str(size(handles.imgs,1)) ')']);
set(handles.axes3,'xticklabel',[]);set(handles.axes3,'yticklabel',[]);

contour1=handles.contours.contour1;
contour2=handles.contours.contour2;
contour3=handles.contours.contour3;

if isempty(contour2)
    uiwait(msgbox('First finish drawing contour1(RED)','Title','modal'));
    return
end

[x y]=ginput(1);
plot(contour1(:,1),contour1(:,2),'r*-');
plot(contour2(:,1),contour2(:,2),'*-');
plot(contour3(:,1),contour3(:,2),'g*-');
ind=dsearchn(contour2,[x y]);
x=contour2(ind,1);y=contour2(ind,2);

handles.LL=[x y];guidata(hObject,handles);
plot(x,y,'c.','markersize',22);

% --- Executes on button press in pushbutton11.
function pushbutton11_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton11 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
hold(handles.axes3,'off');
imagesc(reshape(handles.imgs(handles.randind(handles.framecount),:),68,68),'Parent',handles.axes3);hold(handles.axes3,'on');colormap gray
title([handles.allfiles(handles.filecount).name ' - ' num2str(handles.randind(handles.framecount)) '(' num2str(handles.framecount) ' out of ' num2str(size(handles.imgs,1)) ')']);
set(handles.axes3,'xticklabel',[]);set(handles.axes3,'yticklabel',[]);


contour1=handles.contours.contour1;
contour2=handles.contours.contour2;
contour3=handles.contours.contour3;
if isempty(contour2)
    uiwait(msgbox('First finish drawing contour1(RED)','Title','modal'));
    return
end

[x y]=ginput(1);
plot(contour1(:,1),contour1(:,2),'r*-');
plot(contour2(:,1),contour2(:,2),'*-');
plot(contour3(:,1),contour3(:,2),'g*-');
ind=dsearchn(contour2,[x y]);
x=contour2(ind,1);y=contour2(ind,2);

handles.AVR=[x y];guidata(hObject,handles);
plot(x,y,'c.','markersize',22);

% --- Executes on button press in pushbutton12.
function pushbutton12_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton12 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
hold(handles.axes3,'off');
imagesc(reshape(handles.imgs(handles.randind(handles.framecount),:),68,68),'Parent',handles.axes3);hold(handles.axes3,'on');colormap gray
title([handles.allfiles(handles.filecount).name ' - ' num2str(handles.randind(handles.framecount)) '(' num2str(handles.framecount) ' out of ' num2str(size(handles.imgs,1)) ')']);
set(handles.axes3,'xticklabel',[]);set(handles.axes3,'yticklabel',[]);


contour1=handles.contours.contour1;
contour2=handles.contours.contour2;
contour3=handles.contours.contour3;

if isempty(contour1)
    uiwait(msgbox('First finish drawing contour1(RED)','Title','modal'));
    return
end

[x y]=ginput(1);
plot(contour1(:,1),contour1(:,2),'r*-');
plot(contour2(:,1),contour2(:,2),'*-');
plot(contour3(:,1),contour3(:,2),'g*-');
ind=dsearchn(contour1,[x y]);
x=contour1(ind,1);y=contour1(ind,2);

handles.VEL=[x y];guidata(hObject,handles);
plot(x,y,'c.','markersize',22);

% --- Executes on button press in pushbutton13.
function pushbutton13_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton13 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
hold(handles.axes3,'off');
imagesc(reshape(handles.imgs(handles.randind(handles.framecount),:),68,68),'Parent',handles.axes3);hold(handles.axes3,'on');colormap gray
title([handles.allfiles(handles.filecount).name ' - ' num2str(handles.randind(handles.framecount)) '(' num2str(handles.framecount) ' out of ' num2str(size(handles.imgs,1)) ')']);
set(handles.axes3,'xticklabel',[]);set(handles.axes3,'yticklabel',[]);


contour1=handles.contours.contour1;
contour2=handles.contours.contour2;
contour3=handles.contours.contour3;
if isempty(contour3)
    uiwait(msgbox('First finish drawing contour1(RED)','Title','modal'));
    return
end

[x y]=ginput(1);
plot(contour1(:,1),contour1(:,2),'r*-');
plot(contour2(:,1),contour2(:,2),'*-');
plot(contour3(:,1),contour3(:,2),'g*-');
ind=dsearchn(contour3,[x y]);
x=contour3(ind,1);y=contour3(ind,2);

handles.GLTB=[x y];guidata(hObject,handles);
plot(x,y,'c.','markersize',22);
