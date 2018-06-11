[filename, pathname] = uigetfile('*.*','File Selector');
cd(pathname)
temp = xlsread(filename,-1);

Time = temp(:,1:2:end);  % odd matrix
Length = temp(:,2:2:end);  % even matrix

for f = 1:size(Time,2)
    Cell1(:,1) = Time(:,f);
    Cell1(:,2) = Length(:,f);
    Cell1(isnan(Cell1(:,1)),:)=[];

    prompt = {strcat('Enter Data ID For MT#_',num2str(f))};
    dlg_title = 'Input';
    num_lines = 1;
    def = {num2str(f)};
    answer = inputdlg(prompt,dlg_title,num_lines,def);
    date = answer{1};
    date = cellstr(date);

    SM1 = smooth(Cell1(:,2));

    SM2 = SM1;
    SM2(:,2) = SM2(:,1);
    SM2(:,1) = Cell1(:,1);
    [maxima, maxtime] = findpeaks(SM2(:,2),SM2(:,1));
    Invert = SM2;
    Invert(:,2) = Invert(:,2) * -1; 
    [minima, mintime] = findpeaks(Invert(:,2),Invert(:,1));
    minima = abs(minima);
    maxtime(:,2) = maxima;
    mintime(:,2) = minima;
    timepoints = vertcat(maxtime, mintime);
    timepointsDS = mat2dataset(timepoints);
    timepointsDS = sortrows(timepointsDS,'timepoints1','ascend');
    NPoints = size(timepointsDS,1);
    if NPoints > 1
        for i = 1:NPoints-1
            d =  exist('Data');
            if i <= 1 
                TP1 = timepointsDS.timepoints1(i);
            elseif d == 1; 
                TP1 = Data.End_Time(end);
            elseif d == 0; 
                i = i+1;
            end
           TP2 = timepointsDS.timepoints1(i+1);
           temp1 = find(Cell1(:,1) == TP1);
           temp2 = find(Cell1(:,1) == TP2);
           [Section1] = Cell1(temp1:temp2-1,:);
           [Section2] = Cell1(temp1:temp2,:);
           [Section3] = Cell1(temp1:temp2+1,:);

           if size(Section1,1) >= 3
               [curve, goodness1] = fit(Section1(:,1),Section1(:,2),'poly1');
           elseif size(Section2,1) >= 3
               [curve, goodness1] = fit(Section2(:,1),Section2(:,2),'poly1');
           end
           if size(Section2,1) >= 3
               [curve, goodness1(2)] = fit(Section2(:,1),Section2(:,2),'poly1');
           else
           end

            if size(Section3,1) >= 3
               [curve, goodness1(3)] = fit(Section3(:,1),Section3(:,2),'poly1');
           else
           end

            exist goodness1 'var';
           d = ans;
            if d == 1
               rsquare = [goodness1.rsquare].';
               t = find(rsquare == max(rsquare),1);
               Section = eval(strcat('Section',num2str(t)));
               clear goodness1
               if size(Section,1) >= 3
                   Title = i;
                   R = corrcoef(Section(:,1),Section(:,2));
                   R = R(1,2);
                   [curve, goodness] = fit(Section(:,1),Section(:,2),'poly1');
                   goodness.MT_Number = date;
                   goodness.Section_Number = Title;
                   goodness.Start_Time = Section(1,1);
                   goodness.End_Time = Section(end,1);
                   goodness.Start_Length = Section(1,2);
                   goodness.End_Length = Section(end,2);
                   goodness.Duration = goodness.End_Time - goodness.Start_Time; 
                    if R < 0
                       goodness.Polyermization_Rate = 0;
                       goodness.Depolymerization_Rate = abs(((goodness.End_Length - ...
                            goodness.Start_Length)./goodness.Duration)*60);
                        goodness.L_Change = goodness.Start_Length - ... 
                            goodness.End_Length;
                    elseif R > 0
                       goodness.Polyermization_Rate = (((goodness.End_Length - ...
                            goodness.Start_Length)./goodness.Duration)*60);
                       goodness.Depolymerization_Rate = 0;
                       goodness.L_Change = goodness.End_Length - ... 
                           goodness.Start_Length;
                    else 
                        goodness.Polyermization_Rate = 0;
                       goodness.Depolymerization_Rate = 0;
                       goodness.L_Change = 0;
                    end
                    clear ans
                   exist Data 'var';
                   d = ans;
                    if d == 0
                        Data = struct2dataset(goodness);
                        Data = Data(:, [6:12 15 13 14 1:5]);
                    elseif d == 1
                        TempData = struct2dataset(goodness);
                        TempData = TempData(:, [6:12 15 13 14 1:5]);
                        Data = [Data; TempData];
                    end
                    clear ans
               else
               end
            else
            end
        end

        Valid = Data(Data.rsquare >= 0.8 & Data.L_Change >= 0.5,:);
        Poly_number = sum(Valid.Polyermization_Rate > 0);
        Depoly_number = sum(Valid.Depolymerization_Rate > 0);
        first = min(Valid.Start_Time);
        last = max(Valid.End_Time);
        Total_Duration = last - first;

        Total_Depoly_time = sum(Valid.Duration(Valid.Depolymerization_Rate > 0));
        Total_Poly_time = sum(Valid.Duration(Valid.Polyermization_Rate > 0));

        Rescue_Freq = (Poly_number ./ (Total_Duration - Total_Poly_time))*60; 

        Cat_Freq = (Depoly_number ./ (Total_Duration - Total_Depoly_time))*60;

        Valid.Rescue_Num = Poly_number;
        Valid.Rescue_Freq = Rescue_Freq;
        Valid.Cat_Num = Depoly_number;
        Valid.Cat_Freq = Cat_Freq;
        Valid.Total_Poly_Time = Total_Poly_time;
        Valid.Total_Depoly_Time = Total_Depoly_time;

        P = Valid.Section_Number;
        Paused = Data;
        for i = 1:size(P,1)
            temp1 = find(Paused.Section_Number(:) ==  P(i,1));
            Paused(temp1,:) = [];
        end

        Paused_Dur = (Total_Duration - (Total_Depoly_time + Total_Poly_time));
        Percent_Paused = Paused_Dur./Total_Duration*100;
        Valid.Percent_Paused = Percent_Paused;
        Valid.Dynamicity = sum(Valid.L_Change)/sum(Valid.Duration);

        h = figure
        title(strcat(Title,'__Keep: Y or N'))
        hold on
        pause(0.25)
        plot(Cell1(:,1),Cell1(:,2),Cell1(:,1),SM2(:,2))

        for k = 1:size(Valid,1)
            x = [Valid.Start_Time(k) Valid.End_Time(k)];
            y = [Valid.Start_Length(k) Valid.End_Length(k)];
            plot(x,y,'r--','LineWidth',3,'MarkerSize',10)
        end

        hold off
        w = waitforbuttonpress;
        if w
            p = get(gcf,'CurrentCharacter');
            disp(p)
        end

        if p == 'y'
            exist Data_Master 'var';
               d = ans;
                if d == 0
                    Data_Master = Data;
                    Paused_Master = Paused;
                    Valid_Master = Valid;
                elseif d == 1
                    Data_Master = [Data_Master; Data];
                    Paused_Master = [Paused_Master; Paused];
                    Valid_Master = [Valid_Master; Valid];
                end
                clear Valid Data Paused curve Cell1 ans d
        elseif p == 'n'
            exist Data_Errors 'var';
               d = ans;
                if d == 0
                    Data_Errors = Data;
                    Paused_Errors = Paused;
                    Valid_Errors = Valid;
                elseif d == 1
                    Data_Errors = [Data_Errors; Data];
                    Paused_Errors = [Paused_Errors; Paused];
                    Valid_Errors = [Valid_Errors; Valid];
                end
            clear Valid Data Paused curve Cell1 ans d
        end
        clear ans Cat_Freq Depoly_number goodness i Invert maxima maxtime minima ... 
            mintime NPoints Poly_number R Rescue_Freq Section SM1 temp1 temp2 ... 
            TempData timepoints timepointsDS Title Total_Duration TP1 TP2 ...
            rsquare Section1 Section2 Section3 Section4 Section5 Section6 ...
            Section7 Section8 Section9 SM2 t P Percent_Paused Paused_Dur d ... 
            prompt num_lines dlg_title def date answer first k last p ...
            Total_Depoly_time Total_Poly_time w x x1 x2 y y1 y2 h final
        close all
    else
        clear ans Cat_Freq Depoly_number goodness i Invert maxima maxtime minima ... 
            mintime NPoints Poly_number R Rescue_Freq Section SM1 temp1 temp2 ... 
            TempData timepoints timepointsDS Title Total_Duration TP1 TP2 ...
            rsquare Section1 Section2 Section3 Section4 Section5 Section6 ...
            Section7 Section8 Section9 SM2 t P Percent_Paused Paused_Dur d ... 
            prompt num_lines dlg_title def date answer first k last p ...
            Total_Depoly_time Total_Poly_time w x x1 x2 y y1 y2 h final Cell1
        close all
    end
end

clear f

Dynamicity = double(Valid_Master(Valid_Master.Dynamicity > 0, 23));
Poly_Rate = double(Valid_Master(Valid_Master.Polyermization_Rate >0,9));
Rescue_F = double(Valid_Master(Valid_Master.Rescue_Freq > 0, 17));
Catastrophe_F = double(Valid_Master(Valid_Master.Cat_Freq > 0, 19));
Poly_Dur = Valid_Master.Duration(Valid_Master.Polyermization_Rate > 0,:);
Depoly_Dur = Valid_Master.Duration(Valid_Master.Depolymerization_Rate > 0,:);
Depoly_Rate = double(Valid_Master(Valid_Master.Depolymerization_Rate >0,10));
Percent_Paused = unique(Valid_Master.Percent_Paused);
ave_length = Length(Length > 0);
