%% TITLE AND PURPOSE
% A4 - Statisk dimensionering af cirkulaer akseldiameter
%
% Brug dette script naar My, Mz, T og eventuel N er kendte i et eller
% flere kritiske snit, og den noedvendige akseldiameter skal findes.
%
% Brug ikke scriptet naar reaktioner eller momentdiagrammer foerst skal
% bestemmes (brug A2), naar en kendt diameter blot skal kontrolleres
% (brug A1), eller naar udmattelse er dimensionerende (brug A3).
%
% Bestem manuelt foer brug:
% - kritiske snit og snitkraefter;
% - flydespaending/tilladt spaending og sikkerhedskrav;
% - Kt-faktorer fra kursusfigur eller tabel;
% - eventuel standarddiameterliste fra opgaven eller kataloget.
%
% Scriptet giver kontinuerte diametre for aksiallast, boejning, torsion
% og kombineret von Mises-belastning. Et kontinuerligt resultat kaldes
% ikke et standardmaal, medmindre en standardliste er leveret.

clear; clc; close all;

%% ASSUMPTIONS AND MANUAL INPUT
% Enheder: N, mm og MPa. Momenter indtastes i N*m og omregnes til N*mm.
% N > 0 er traek. Fortegn paa My, Mz og T paavirker ikke diameterkravet.
%
% Akslen er massiv eller hul med et FAST forhold k = di/D under
% dimensioneringen. Hvis di er fast uafhaengigt af D, skal modellen
% aendres.
%
% Statisk kursuskriterium:
% sigma_vm = sqrt(sigma_normal,worst^2 + 3*tau^2)
%
% sigma_normal,worst = |Kt_a*N/A| + Kt_b*Mres/Wb
% tau                = Kt_t*|T|/Wt
%
% A  = pi/4  * D^2 * (1-k^2)
% Wb = pi/32 * D^3 * (1-k^4)
% Wt = pi/16 * D^3 * (1-k^4)

%% INPUT
% ----- Lasttilfaelde: alle vektorer skal have samme laengde -----
loadCaseNames = ["Eksempel-eksamen, problem 4"]; % [-] Navn pr. case
bendingMomentY_Nm = -62;    % [N*m] My
bendingMomentZ_Nm = -78;    % [N*m] Mz
torque_Nm = 26;             % [N*m] T
axialForce_N = 0;           % [N] N, positiv i traek

% ----- Tvaersnit -----
shaftSectionType = "solid"; % "solid" eller "hollowRatio"
innerToOuterDiameterRatio = 0.00; % [-] k=di/D

% ----- Statiske spaendingskoncentrationer -----
% Hver faktor maa vaere en skalar eller én vaerdi pr. lasttilfaelde.
Kt_bending = 1.00;          % [-] Kt for boejning
Kt_torsion = 1.00;          % [-] Kt for torsion
Kt_axial = 1.00;            % [-] Kt for aksiallast

% ----- Materialekrav -----
% "yieldSafety": sigma_till = Re/requiredSafetyFactor
% "allowableStress": anvend allowableEquivalentStressInput_MPa direkte
strengthInputMode = "yieldSafety";
yieldStrength_MPa = 240;                 % [MPa] Re
requiredSafetyFactor = 2.00;             % [-] n_krav
allowableEquivalentStressInput_MPa = 120;% [MPa] Direkte sigma_VM,till

% ----- Praktisk diameter og LEVERET standardliste -----
chosenPracticalOuterDiameter_mm = 30;    % [mm] NaN deaktiverer kontrol
providedStandardOuterDiameters_mm = [];  % [mm] Ingen skjult standardserie

% ----- Numerik og tests -----
rootRelativeTolerance = 1e-10;           % [-] fzero-kontrol
runCourseTests = true;                   % [logisk] Koer tests

%% UNIT CHECK AND VALIDATION
assert(ismember(shaftSectionType, ["solid","hollowRatio"]), ...
    'shaftSectionType skal vaere "solid" eller "hollowRatio".');
assert(ismember(strengthInputMode, ["yieldSafety","allowableStress"]), ...
    'Ukendt strengthInputMode.');

loadCaseNames = loadCaseNames(:);
bendingMomentY_Nm = bendingMomentY_Nm(:);
bendingMomentZ_Nm = bendingMomentZ_Nm(:);
torque_Nm = torque_Nm(:);
axialForce_N = axialForce_N(:);
caseCount = numel(loadCaseNames);

assert(caseCount >= 1, 'Angiv mindst ét lasttilfaelde.');
assert(all([numel(bendingMomentY_Nm),numel(bendingMomentZ_Nm), ...
    numel(torque_Nm),numel(axialForce_N)] == caseCount), ...
    'Alle lastvektorer og loadCaseNames skal have samme laengde.');
assert(all(isfinite([bendingMomentY_Nm;bendingMomentZ_Nm; ...
    torque_Nm;axialForce_N])), 'Alle laster skal vaere endelige.');

Kt_bending = expandFactor(Kt_bending,caseCount,'Kt_bending');
Kt_torsion = expandFactor(Kt_torsion,caseCount,'Kt_torsion');
Kt_axial = expandFactor(Kt_axial,caseCount,'Kt_axial');
assert(all([Kt_bending;Kt_torsion;Kt_axial] >= 1), ...
    'Statiske Kt-faktorer skal vaere >= 1.');

if shaftSectionType == "solid"
    if abs(innerToOuterDiameterRatio) > 1e-12
        warning('Massiv aksel: di/D saettes til 0.');
    end
    innerToOuterDiameterRatio = 0;
else
    assert(isfinite(innerToOuterDiameterRatio) && ...
        innerToOuterDiameterRatio > 0 && innerToOuterDiameterRatio < 1, ...
        'Hul aksel kraever 0 < di/D < 1.');
end
if innerToOuterDiameterRatio > 0.90
    warning('Meget tyndvaegget aksel: kontroller modellens gyldighed.');
end

if strengthInputMode == "yieldSafety"
    assert(isfinite(yieldStrength_MPa) && yieldStrength_MPa > 0, ...
        'Flydespaendingen skal vaere positiv.');
    assert(isfinite(requiredSafetyFactor) && requiredSafetyFactor > 0, ...
        'Sikkerhedskravet skal vaere positivt.');
    allowableEquivalentStress_MPa = yieldStrength_MPa/requiredSafetyFactor;
else
    assert(isfinite(allowableEquivalentStressInput_MPa) && ...
        allowableEquivalentStressInput_MPa > 0, ...
        'Direkte tilladt spaending skal vaere positiv.');
    allowableEquivalentStress_MPa = allowableEquivalentStressInput_MPa;
    assert(isnan(yieldStrength_MPa) || ...
        (isfinite(yieldStrength_MPa) && yieldStrength_MPa > 0), ...
        'Re skal vaere positiv eller NaN.');
end

assert(isnan(chosenPracticalOuterDiameter_mm) || ...
    (isfinite(chosenPracticalOuterDiameter_mm) && ...
    chosenPracticalOuterDiameter_mm > 0), ...
    'Valgt diameter skal vaere positiv eller NaN.');

providedStandardOuterDiameters_mm = ...
    sort(unique(providedStandardOuterDiameters_mm(:)));
assert(all(isfinite(providedStandardOuterDiameters_mm)) && ...
    all(providedStandardOuterDiameters_mm > 0), ...
    'Standarddiametre skal vaere positive og endelige.');
assert(rootRelativeTolerance > 0 && rootRelativeTolerance < 1e-3, ...
    'rootRelativeTolerance skal vaere positiv og lille.');
assert(islogical(runCourseTests) && isscalar(runCourseTests), ...
    'runCourseTests skal vaere true eller false.');

%% CALCULATION
% Momenter: N*m -> N*mm
My_Nmm = bendingMomentY_Nm*1e3;
Mz_Nmm = bendingMomentZ_Nm*1e3;
T_Nmm = torque_Nm*1e3;
Mres_Nmm = hypot(My_Nmm,Mz_Nmm);
Mres_Nm = Mres_Nmm/1e3;
k = innerToOuterDiameterRatio;
sigmaAllow_MPa = allowableEquivalentStress_MPa;

% Enkeltkriterier
D_axial_mm = sqrt(4*Kt_axial.*abs(axialForce_N) ./ ...
    (pi*(1-k^2)*sigmaAllow_MPa));
D_bending_mm = (32*Kt_bending.*Mres_Nmm ./ ...
    (pi*(1-k^4)*sigmaAllow_MPa)).^(1/3);
D_torsionVM_mm = (16*sqrt(3)*Kt_torsion.*abs(T_Nmm) ./ ...
    (pi*(1-k^4)*sigmaAllow_MPa)).^(1/3);

% Kombineret kriterium
D_combinedVM_mm = zeros(caseCount,1);
controlType = strings(caseCount,1);
dominantSingleContribution = strings(caseCount,1);
criterionNames = ["Aksial","Boejning","Torsion"];

for i = 1:caseCount
    D_combinedVM_mm(i) = requiredDiameterVM(axialForce_N(i), ...
        Mres_Nmm(i),T_Nmm(i),Kt_axial(i),Kt_bending(i), ...
        Kt_torsion(i),k,sigmaAllow_MPa,rootRelativeTolerance);

    active = [abs(axialForce_N(i))>0,Mres_Nmm(i)>0,abs(T_Nmm(i))>0];
    if sum(active)==0
        controlType(i) = "Ingen belastning";
    elseif sum(active)==1 && active(1)
        controlType(i) = "Ren aksiallast";
    elseif sum(active)==1 && active(2)
        controlType(i) = "Ren boejning";
    elseif sum(active)==1 && active(3)
        controlType(i) = "Ren torsion";
    else
        controlType(i) = "Kombineret von Mises";
    end

    singleD = [D_axial_mm(i),D_bending_mm(i),D_torsionVM_mm(i)];
    if all(singleD==0)
        dominantSingleContribution(i) = "Ingen";
    else
        [~,j] = max(singleD);
        dominantSingleContribution(i) = criterionNames(j);
    end
end

[requiredOuterDiameter_mm,governingCaseIndex] = max(D_combinedVM_mm);
requiredInnerDiameter_mm = k*requiredOuterDiameter_mm;
governingCaseName = loadCaseNames(governingCaseIndex);

% Automatisk standardvalg kun fra den leverede liste
selectedStandardOuterDiameter_mm = NaN;
selectedStandardInnerDiameter_mm = NaN;
if ~isempty(providedStandardOuterDiameters_mm)
    idx = find(providedStandardOuterDiameters_mm >= ...
        requiredOuterDiameter_mm,1,'first');
    if ~isempty(idx)
        selectedStandardOuterDiameter_mm = ...
            providedStandardOuterDiameters_mm(idx);
        selectedStandardInnerDiameter_mm = ...
            k*selectedStandardOuterDiameter_mm;
    end
end

% Kontrol af praktisk og eventuel standarddiameter
chosenCheckTable = table;
chosenMaxUtilization = NaN;
chosenMinYieldSafety = NaN;
chosenStatus = "IKKE KONTROLLERET";

if isfinite(chosenPracticalOuterDiameter_mm)
    chosenCheckTable = checkDiameter(chosenPracticalOuterDiameter_mm,k, ...
        loadCaseNames,axialForce_N,Mres_Nmm,T_Nmm,Kt_axial, ...
        Kt_bending,Kt_torsion,sigmaAllow_MPa,yieldStrength_MPa);
    chosenMaxUtilization = max(chosenCheckTable.Utilization);
    chosenMinYieldSafety = min(chosenCheckTable.YieldSafety,[],'omitnan');
    if chosenMaxUtilization <= 1 + 10*rootRelativeTolerance
        chosenStatus = "OK";
    else
        chosenStatus = "IKKE OK";
    end
end

standardCheckTable = table;
standardMaxUtilization = NaN;
standardStatus = "IKKE VALGT";

if isfinite(selectedStandardOuterDiameter_mm)
    standardCheckTable = checkDiameter(selectedStandardOuterDiameter_mm,k, ...
        loadCaseNames,axialForce_N,Mres_Nmm,T_Nmm,Kt_axial, ...
        Kt_bending,Kt_torsion,sigmaAllow_MPa,yieldStrength_MPa);
    standardMaxUtilization = max(standardCheckTable.Utilization);
    if standardMaxUtilization <= 1 + 10*rootRelativeTolerance
        standardStatus = "OK";
    else
        standardStatus = "IKKE OK";
    end
end

%% RESULTS
fprintf('\n===== A4: STATISK DIMENSIONERING AF AKSELDIAMETER =====\n');
fprintf('Tvaersnitstype:                    %s\n',char(shaftSectionType));
fprintf('Forhold di/D:                      %.4f\n',k);
fprintf('Tilladt von Mises-spaending:       %.3f MPa\n',sigmaAllow_MPa);
if strengthInputMode == "yieldSafety"
    fprintf('Flydespaending:                    %.3f MPa\n',yieldStrength_MPa);
    fprintf('Kraevet sikkerhed:                 %.3f\n',requiredSafetyFactor);
end

diameterResultsTable = table(loadCaseNames,Mres_Nm,torque_Nm, ...
    axialForce_N,Kt_bending,Kt_torsion,Kt_axial,D_axial_mm, ...
    D_bending_mm,D_torsionVM_mm,D_combinedVM_mm, ...
    dominantSingleContribution,controlType, ...
    'VariableNames',{'Lasttilfaelde','Mres_Nm','T_Nm','N_N', ...
    'Kt_b','Kt_t','Kt_a','D_aksial_mm','D_boejning_mm', ...
    'D_torsionVM_mm','D_kombineretVM_mm', ...
    'StoersteEnkeltbidrag','Kontroltype'});

fprintf('\nKontinuerte diameterkrav pr. lasttilfaelde:\n');
disp(diameterResultsTable);
fprintf('Styrende lasttilfaelde:            %s\n',char(governingCaseName));
fprintf('Kraevet kontinuerlig yderdiameter: %.3f mm\n', ...
    requiredOuterDiameter_mm);
fprintf('Tilhørende indre diameter:         %.3f mm\n', ...
    requiredInnerDiameter_mm);

if isfinite(chosenPracticalOuterDiameter_mm)
    fprintf('\nKontrol af valgt D = %.3f mm:\n', ...
        chosenPracticalOuterDiameter_mm);
    disp(chosenCheckTable);
    fprintf('Maksimal udnyttelse:               %.4f\n', ...
        chosenMaxUtilization);
    if isfinite(chosenMinYieldSafety)
        fprintf('Mindste sikkerhed mod flydning:    %.3f\n', ...
            chosenMinYieldSafety);
    end
end

if isempty(providedStandardOuterDiameters_mm)
    fprintf(['\nIngen standardliste er leveret. Det kontinuerte resultat ', ...
        'er derfor IKKE et standardmaal.\n']);
elseif isfinite(selectedStandardOuterDiameter_mm)
    fprintf('\nValg fra LEVERET standardliste:\n');
    fprintf('Valgt standard-yderdiameter:       %.3f mm\n', ...
        selectedStandardOuterDiameter_mm);
    fprintf('Tilhørende indre diameter:         %.3f mm\n', ...
        selectedStandardInnerDiameter_mm);
    fprintf('Maksimal udnyttelse:               %.4f\n', ...
        standardMaxUtilization);
else
    fprintf(['\nADVARSEL: Ingen leveret standarddiameter er stor nok. ', ...
        'Stoerste leverede maal er %.3f mm.\n'], ...
        max(providedStandardOuterDiameters_mm));
end

results = struct;
results.allowableEquivalentStress_MPa = sigmaAllow_MPa;
results.diameterResultsTable = diameterResultsTable;
results.requiredOuterDiameter_mm = requiredOuterDiameter_mm;
results.requiredInnerDiameter_mm = requiredInnerDiameter_mm;
results.governingCaseName = governingCaseName;
results.chosenCheckTable = chosenCheckTable;
results.chosenStatus = chosenStatus;
results.selectedStandardOuterDiameter_mm = ...
    selectedStandardOuterDiameter_mm;
results.standardCheckTable = standardCheckTable;
results.standardStatus = standardStatus;

%% AUTOMATIC CHECKS
if requiredOuterDiameter_mm == 0
    fprintf('\nADVARSEL: Alle lasttilfaelde er ubelastede.\n');
else
    rootCheck = checkDiameter(requiredOuterDiameter_mm,k, ...
        loadCaseNames(governingCaseIndex), ...
        axialForce_N(governingCaseIndex),Mres_Nmm(governingCaseIndex), ...
        T_Nmm(governingCaseIndex),Kt_axial(governingCaseIndex), ...
        Kt_bending(governingCaseIndex),Kt_torsion(governingCaseIndex), ...
        sigmaAllow_MPa,yieldStrength_MPa);
    assert(abs(rootCheck.Utilization-1) <= ...
        100*rootRelativeTolerance,'Rodkontrollen fejlede.');
    fprintf('OK: Den styrende kontinuerte diameter giver udnyttelse 1.\n');
end

if isfinite(chosenPracticalOuterDiameter_mm)
    if chosenStatus == "OK"
        fprintf('OK: Den valgte praktiske diameter opfylder kravet.\n');
    else
        fprintf(['IKKE OK: Den valgte praktiske diameter er for lille; ', ...
            'maksimal udnyttelse er %.4f.\n'],chosenMaxUtilization);
    end
else
    fprintf('ADVARSEL: Ingen praktisk diameter er angivet.\n');
end

if ~isempty(providedStandardOuterDiameters_mm)
    if standardStatus == "OK"
        fprintf('OK: Valget fra den leverede standardliste opfylder kravet.\n');
    elseif standardStatus == "IKKE OK"
        fprintf('IKKE OK: Standardvalget bestod ikke efterkontrollen.\n');
    else
        fprintf('IKKE OK: Den leverede standardliste er utilstraekkelig.\n');
    end
end

%% PLOTS
if requiredOuterDiameter_mm > 0
    figure('Name','A4 - Diameterkrav');
    bar(D_combinedVM_mm);
    hold on;
    if isfinite(chosenPracticalOuterDiameter_mm)
        yline(chosenPracticalOuterDiameter_mm,'--','Valgt praktisk D');
    end
    if isfinite(selectedStandardOuterDiameter_mm)
        yline(selectedStandardOuterDiameter_mm,':','Valgt standard D');
    end
    grid on;
    xlabel('Lasttilfaelde');
    ylabel('Noedvendig yderdiameter D [mm]');
    title('Kontinuerligt diameterkrav fra von Mises');
    xticks(1:caseCount);
    xticklabels(loadCaseNames);
    xtickangle(20);

    candidates = [requiredOuterDiameter_mm; ...
        chosenPracticalOuterDiameter_mm;selectedStandardOuterDiameter_mm];
    candidates = candidates(isfinite(candidates));
    diameterSweep_mm = linspace(max(0.5*requiredOuterDiameter_mm,1e-3), ...
        1.35*max(candidates),250);
    utilizationEnvelope = zeros(size(diameterSweep_mm));

    for j = 1:numel(diameterSweep_mm)
        sweepTable = checkDiameter(diameterSweep_mm(j),k,loadCaseNames, ...
            axialForce_N,Mres_Nmm,T_Nmm,Kt_axial,Kt_bending, ...
            Kt_torsion,sigmaAllow_MPa,yieldStrength_MPa);
        utilizationEnvelope(j) = max(sweepTable.Utilization);
    end

    figure('Name','A4 - Udnyttelse');
    plot(diameterSweep_mm,utilizationEnvelope,'LineWidth',1.6);
    hold on;
    yline(1,'--','Tilladt udnyttelse');
    xline(requiredOuterDiameter_mm,':','Kontinuerligt krav');
    if isfinite(chosenPracticalOuterDiameter_mm)
        plot(chosenPracticalOuterDiameter_mm,chosenMaxUtilization,'o', ...
            'MarkerSize',8,'LineWidth',1.5);
    end
    grid on;
    xlabel('Yderdiameter D [mm]');
    ylabel('Maksimal udnyttelse \sigma_{VM}/\sigma_{till} [-]');
    title('Styrende statisk udnyttelse');
end

%% PHYSICAL CONCLUSION
fprintf('\n===== FYSISK KONKLUSION =====\n');
fprintf(['Det styrende lasttilfaelde er "%s". Det kontinuerte krav er ', ...
    'D = %.3f mm.\n'],char(governingCaseName),requiredOuterDiameter_mm);

if k > 0
    fprintf('Resultatet forudsaetter et konstant forhold di/D = %.4f.\n',k);
end

if isfinite(chosenPracticalOuterDiameter_mm)
    fprintf('Den valgte praktiske diameter er vurderet som: %s.\n', ...
        char(chosenStatus));
end

fprintf(['Resultatet afhaenger af korrekt kritisk snit, snitkraefter, ', ...
    'materialedata, sikkerhedskrav og Kt-opslag. Udmattelse, ', ...
    'deformation og kritisk omdrejningstal er ikke kontrolleret.\n']);

%% OPTIONAL TEST CASES
if runCourseTests
    fprintf('\n===== INDBYGGEDE A4-TESTS =====\n');

    % 1) Haandkontrol: ren boejning
    Mtest_Nmm = 500e3;
    sigmaTest_MPa = 100;
    Db_expected = (32*Mtest_Nmm/(pi*sigmaTest_MPa))^(1/3);
    Db_calculated = requiredDiameterVM(0,Mtest_Nmm,0,1,1,1, ...
        0,sigmaTest_MPa,1e-12);

    % 2) Haandkontrol: ren torsion efter von Mises
    Ttest_Nmm = 250e3;
    Dt_expected = (16*sqrt(3)*Ttest_Nmm/(pi*sigmaTest_MPa))^(1/3);
    Dt_calculated = requiredDiameterVM(0,0,Ttest_Nmm,1,1,1, ...
        0,sigmaTest_MPa,1e-12);

    % 3) Omvendt kursuscase:
    % D=30 mm, My=-62 N*m, Mz=-78 N*m, T=26 N*m gav n ca. 6.23.
    Dcourse = requiredDiameterVM(0,hypot(-62,-78)*1e3,26e3, ...
        1,1,1,0,240/6.23,1e-12);

    % 4) Randtilfaelde: 90 % af korrekt boejningsdiameter
    Dsmall = 0.90*Db_calculated;
    [~,~,~,~,vmSmall] = stressAtD(Dsmall,0,0,Mtest_Nmm,0,1,1,1);
    utilizationSmall = vmSmall/sigmaTest_MPa;

    testName = ["Ren boejning";"Ren torsion"; ...
        "Omvendt kursuscase";"Underdimensioneret D"];
    calculatedValue = [Db_calculated;Dt_calculated;Dcourse; ...
        utilizationSmall];
    referenceValue = [Db_expected;Dt_expected;30.00;1/0.90^3];
    tolerance = [1e-8;1e-8;0.01;1e-8];
    passed = abs(calculatedValue-referenceValue) <= tolerance;

    testResults = table(testName,calculatedValue,referenceValue, ...
        tolerance,passed);
    disp(testResults);
    assert(all(passed),'Mindst én A4-test fejlede.');
    assert(utilizationSmall > 1, ...
        'Randtilfaeldet skulle give IKKE OK.');
    fprintf(['OK: Haandkontroller, kursuscase og ', ...
        'randtilfaelde er bestaaet.\n']);
end

%% LOCAL FUNCTIONS
function factor = expandFactor(value,caseCount,name)
% En skalar genbruges; ellers kraeves én vaerdi pr. lasttilfaelde.
value = value(:);
if isscalar(value)
    factor = repmat(value,caseCount,1);
elseif numel(value)==caseCount
    factor = value;
else
    error('%s skal vaere skalar eller have én vaerdi pr. case.',name);
end
assert(all(isfinite(factor)),'%s skal indeholde endelige tal.',name);
end

function Dreq = requiredDiameterVM(N,Mres_Nmm,T_Nmm,Kta,Ktb,Ktt, ...
    k,sigmaAllow_MPa,relativeTolerance)
% Monoton fzero-soegning for sigma_vm(D)=sigma_till.
if N==0 && Mres_Nmm==0 && T_Nmm==0
    Dreq = 0;
    return;
end

Da = sqrt(4*Kta*abs(N)/(pi*(1-k^2)*sigmaAllow_MPa));
Db = (32*Ktb*Mres_Nmm/(pi*(1-k^4)*sigmaAllow_MPa))^(1/3);
Dt = (16*sqrt(3)*Ktt*abs(T_Nmm)/ ...
    (pi*(1-k^4)*sigmaAllow_MPa))^(1/3);
Dsingle = max([Da,Db,Dt]);

residual = @(D) vonMisesAtD(D,k,N,Mres_Nmm,T_Nmm,Kta,Ktb,Ktt) ...
    - sigmaAllow_MPa;

Dlow = max(0.5*Dsingle,1e-9);
Dhigh = max(Dsingle,1e-6);
rHigh = residual(Dhigh);

if abs(rHigh) <= relativeTolerance*sigmaAllow_MPa
    Dreq = Dhigh;
    return;
end

counter = 0;
while rHigh > 0
    Dhigh = 2*Dhigh;
    rHigh = residual(Dhigh);
    counter = counter+1;
    if counter > 100
        error('Kunne ikke indkredse diameterroden. Kontroller input.');
    end
end

assert(residual(Dlow)>0 && rHigh<=0,'Ugyldigt fzero-interval.');
Dreq = fzero(residual,[Dlow,Dhigh]);
assert(abs(residual(Dreq)) <= ...
    100*relativeTolerance*sigmaAllow_MPa, ...
    'fzero-resultatet opfylder ikke tolerancen.');
end

function sigmaVM_MPa = vonMisesAtD(D,k,N,Mres_Nmm,T_Nmm,Kta,Ktb,Ktt)
[~,~,~,~,sigmaVM_MPa] = stressAtD(D,k,N,Mres_Nmm,T_Nmm,Kta,Ktb,Ktt);
end

function [sigmaA_MPa,sigmaB_MPa,tauT_MPa,sigmaWorst_MPa, ...
    sigmaVM_MPa] = stressAtD(D,k,N,Mres_Nmm,T_Nmm,Kta,Ktb,Ktt)
% Lokale statiske spaendinger ved en given yderdiameter.
assert(D>0,'Diameteren skal vaere positiv.');
A_mm2 = pi/4*D^2*(1-k^2);
Wb_mm3 = pi/32*D^3*(1-k^4);
Wt_mm3 = pi/16*D^3*(1-k^4);

sigmaA_MPa = Kta*N/A_mm2;
sigmaB_MPa = Ktb*Mres_Nmm/Wb_mm3;
tauT_MPa = Ktt*abs(T_Nmm)/Wt_mm3;
sigmaWorst_MPa = abs(sigmaA_MPa)+sigmaB_MPa;
sigmaVM_MPa = sqrt(sigmaWorst_MPa^2+3*tauT_MPa^2);
end

function resultTable = checkDiameter(D,k,names,N,Mres_Nmm,T_Nmm, ...
    Kta,Ktb,Ktt,sigmaAllow_MPa,Re_MPa)
% Efterkontrol af alle lasttilfaelde ved én diameter.
caseCount = numel(names);
sigmaA = zeros(caseCount,1);
sigmaB = zeros(caseCount,1);
tauT = zeros(caseCount,1);
sigmaWorst = zeros(caseCount,1);
sigmaVM = zeros(caseCount,1);

for i = 1:caseCount
    [sigmaA(i),sigmaB(i),tauT(i),sigmaWorst(i),sigmaVM(i)] = ...
        stressAtD(D,k,N(i),Mres_Nmm(i),T_Nmm(i), ...
        Kta(i),Ktb(i),Ktt(i));
end

utilization = sigmaVM/sigmaAllow_MPa;
if isfinite(Re_MPa)
    yieldSafety = Re_MPa./sigmaVM;
    yieldSafety(sigmaVM==0) = Inf;
else
    yieldSafety = NaN(caseCount,1);
end

status = repmat("OK",caseCount,1);
status(utilization>1) = "IKKE OK";

resultTable = table(names(:),repmat(D,caseCount,1),sigmaA,sigmaB, ...
    tauT,sigmaWorst,sigmaVM,utilization,yieldSafety,status, ...
    'VariableNames',{'Lasttilfaelde','D_mm','sigmaA_MPa', ...
    'sigmaB_MPa','tauT_MPa','sigmaNormalWorst_MPa','sigmaVM_MPa', ...
    'Utilization','YieldSafety','Status'});
end
