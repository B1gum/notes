%% B4 - KRAFTSPINDEL MED KVADRATISK GEVIND
% Brug dette script når en kraftspindel skal analyseres for geometri,
% løfte-/sænkemoment, effekt, virkningsgrad og selvlåsning.
%
% Brug ikke scriptet direkte til trapez-/Acme-/V-gevind eller til kontrol
% af styrke, knæk, kontakttryk og møtrikkens gevindlængde.
%
% Manuelt før beregningen:
%   1) Bestem d, p og antal gevindstarter n.
%   2) Bestem lasten F eller et kendt løftemoment/-effekt.
%   3) Slå friktion f og f_c op/vælg dem ud fra opgaven.
%   4) Bestem brystets friktionsdiameter d_c.
%
% Kursusgrundlag:
%   d_r = d-p,  d_m = d-p/2,  l = p*n
%   tan(lambda) = l/(pi*d_m)
%   T_R = F*d_m/2*(l+pi*f*d_m)/(pi*d_m-f*l)       (8-1)
%   T_L = F*d_m/2*(pi*f*d_m-l)/(pi*d_m+f*l)       (8-2)
%   T_c = F*f_c*d_c/2                              (8-6)
%   T_0 = F*l/(2*pi),  e_R = T_0/(T_R+T_c)         (8-4)
%   Selvlåsning for selve gevindet: f > tan(lambda)
%
% Standardinputtet svarer til kursusopgave 8-9.

clear; clc; close all;

%% ASSUMPTIONS AND MANUAL INPUT
% Enheder: N, mm, s, N*mm og MPa; momenter udskrives i N*m.
% Gevindet er kvadratisk og højregevind.
% Positivt sænkemoment betyder, at et aktivt moment skal påføres.
% Negativt sænkemoment betyder, at lasten kan drive spindlen.
% Brystmomentet lægges til både løfte- og sænkemoment som i kurset.
% Friktion er konstant; acceleration og inertimomenter negligeres.
% Kursusets sænkevirkningsgrad beregnes kun for T_L,total > 0.

%% INPUT
analysisMode = "knownLoad";
% "knownLoad", "knownRaisingTorque" eller "knownRaisingPower"

axialLoadInput = 10e3;               % [N] Kendt last F
raisingTorqueInput = 82.991;         % [N*m] Kendt samlet løftemoment
raisingPowerInput = 2.086e3;         % [W] Kendt løfteeffekt

nominalScrewDiameter = 40;            % [mm] Spindeldiameter d
threadPitch = 6;                      % [mm] Pitch p
numberOfThreadStarts = 2;             % [-] Antal gevindstarter n

meanDiameterMode = "courseSquare";   % [-] "courseSquare" eller "manual"
threadMeanDiameterManual = NaN;       % [mm] Manuel d_m
rootDiameterManual = NaN;             % [mm] Manuel d_r

threadFrictionCoefficient = 0.10;     % [-] Gevindfriktion f

collarFrictionMode = "included";     % [-] "included" eller "none"
collarFrictionCoefficient = 0.15;     % [-] Brystfriktion f_c
collarMeanDiameterMode = "manual";   % [-] "manual" eller "fromDiameters"
collarMeanDiameterManual = 60;        % [mm] Friktionsdiameter d_c
collarOuterDiameter = NaN;            % [mm] Ydre brystdiameter
collarInnerDiameter = NaN;            % [mm] Indre brystdiameter

speedMode = "linearVelocity";        % [-] "linearVelocity" eller "rpm"
linearVelocityInput = 48;             % [mm/s] Lineær hastighed v
rotationalSpeedInput = 240;           % [rpm] Omdrejningstal

requireThreadSelfLocking = false;    % [-] Krav om selvlåsende gevind
minimumRaisingEfficiency = 0.00;     % [-] Minimumskrav til e_R
makeFrictionSweepPlot = true;         % [-] Vis moment som funktion af f
frictionSweepMaximum = 0.25;          % [-] Maksimal f i parameterplot
runCourseValidationTests = true;     % [-] Test mod opgave 8-4 og 8-9

%% UNIT CHECK AND VALIDATION
assert(any(analysisMode == ["knownLoad","knownRaisingTorque", ...
    "knownRaisingPower"]), 'Ugyldig analysisMode.');
assert(isscalar(nominalScrewDiameter) && nominalScrewDiameter > 0, ...
    'd skal være positiv [mm].');
assert(isscalar(threadPitch) && threadPitch > 0, ...
    'p skal være positiv [mm].');
assert(isscalar(numberOfThreadStarts) && ...
    numberOfThreadStarts == floor(numberOfThreadStarts) && ...
    numberOfThreadStarts >= 1, ...
    'n skal være et positivt heltal.');
assert(isscalar(threadFrictionCoefficient) && ...
    threadFrictionCoefficient >= 0, ...
    'f skal være ikke-negativ.');

switch meanDiameterMode
    case "courseSquare"
        threadDepth = threadPitch/2;
        threadWidth = threadPitch/2;
        rootDiameter = nominalScrewDiameter-threadPitch;
        threadMeanDiameter = nominalScrewDiameter-threadPitch/2;
    case "manual"
        assert(isfinite(threadMeanDiameterManual) && ...
            threadMeanDiameterManual > 0 && ...
            threadMeanDiameterManual < nominalScrewDiameter, ...
            'Manuel d_m er ugyldig.');
        assert(isfinite(rootDiameterManual) && rootDiameterManual > 0 && ...
            rootDiameterManual < threadMeanDiameterManual, ...
            'Manuel d_r er ugyldig.');
        threadMeanDiameter = threadMeanDiameterManual;
        rootDiameter = rootDiameterManual;
        threadDepth = (nominalScrewDiameter-rootDiameter)/2;
        threadWidth = NaN;
    otherwise
        error('Ugyldig meanDiameterMode.');
end

assert(rootDiameter > 0, ...
    'Geometrien giver d_r<=0. Kontrollér d og p.');
assert(rootDiameter < threadMeanDiameter && ...
    threadMeanDiameter < nominalScrewDiameter, ...
    'Der kræves d_r < d_m < d.');

switch collarFrictionMode
    case "included"
        assert(collarFrictionCoefficient >= 0, ...
            'f_c skal være ikke-negativ.');
        switch collarMeanDiameterMode
            case "manual"
                assert(isfinite(collarMeanDiameterManual) && ...
                    collarMeanDiameterManual > 0, ...
                    'd_c skal være positiv.');
                collarMeanDiameter = collarMeanDiameterManual;
            case "fromDiameters"
                assert(isfinite(collarOuterDiameter) && ...
                    isfinite(collarInnerDiameter) && ...
                    collarOuterDiameter > collarInnerDiameter && ...
                    collarInnerDiameter >= 0, ...
                    'Brystdiametrene er ugyldige.');
                collarMeanDiameter = ...
                    (collarOuterDiameter+collarInnerDiameter)/2;
            otherwise
                error('Ugyldig collarMeanDiameterMode.');
        end
        collarFrictionUsed = collarFrictionCoefficient;
    case "none"
        collarFrictionUsed = 0;
        collarMeanDiameter = 0;
    otherwise
        error('Ugyldig collarFrictionMode.');
end

lead = threadPitch*numberOfThreadStarts; % [mm/omdr.]

switch speedMode
    case "linearVelocity"
        assert(linearVelocityInput >= 0, ...
            'v skal være ikke-negativ [mm/s].');
        linearVelocity = linearVelocityInput;
        rotationalFrequency = linearVelocity/lead; % [omdr./s]
        rotationalSpeedRpm = 60*rotationalFrequency;
    case "rpm"
        assert(rotationalSpeedInput >= 0, ...
            'Omdrejningstallet skal være ikke-negativt.');
        rotationalSpeedRpm = rotationalSpeedInput;
        rotationalFrequency = rotationalSpeedRpm/60;
        linearVelocity = rotationalFrequency*lead;
    otherwise
        error('Ugyldig speedMode.');
end
angularVelocity = 2*pi*rotationalFrequency; % [rad/s]

assert(minimumRaisingEfficiency >= 0 && ...
    minimumRaisingEfficiency <= 1, ...
    'Kravet til virkningsgrad skal ligge mellem 0 og 1.');
assert(frictionSweepMaximum > 0, ...
    'frictionSweepMaximum skal være positiv.');

unitLoadCase = calculateB4(1, nominalScrewDiameter, threadPitch, ...
    numberOfThreadStarts, threadMeanDiameter, rootDiameter, ...
    threadFrictionCoefficient, collarFrictionUsed, ...
    collarMeanDiameter, linearVelocity, angularVelocity);

switch analysisMode
    case "knownLoad"
        assert(axialLoadInput >= 0, 'F skal være ikke-negativ [N].');
        axialLoad = axialLoadInput;
    case "knownRaisingTorque"
        assert(raisingTorqueInput >= 0, ...
            'Det kendte moment skal være ikke-negativt.');
        axialLoad = raisingTorqueInput*1e3 / ...
            unitLoadCase.totalRaisingTorque;
    case "knownRaisingPower"
        assert(raisingPowerInput >= 0 && angularVelocity > 0, ...
            'Effekt og vinkelhastighed skal være positive.');
        powerPerNewton = ...
            unitLoadCase.totalRaisingTorque/1e3*angularVelocity;
        axialLoad = raisingPowerInput/powerPerNewton;
end

%% CALCULATION
results = calculateB4(axialLoad, nominalScrewDiameter, threadPitch, ...
    numberOfThreadStarts, threadMeanDiameter, rootDiameter, ...
    threadFrictionCoefficient, collarFrictionUsed, ...
    collarMeanDiameter, linearVelocity, angularVelocity);

results.analysisMode = analysisMode;
results.threadDepth = threadDepth;
results.threadWidth = threadWidth;
results.rotationalFrequency = rotationalFrequency;
results.rotationalSpeedRpm = rotationalSpeedRpm;
results.idealLinearPower = axialLoad*linearVelocity/1e3; % [W]
results.powerConsistencyError = ...
    abs(results.idealPower-results.idealLinearPower);

%% RESULTS
fprintf('\n============================================================\n');
fprintf('B4 - KRAFTSPINDEL MED KVADRATISK GEVIND\n');
fprintf('============================================================\n');
fprintf('Beregningsretning                  = %s\n', analysisMode);

fprintf('\nGEOMETRI OG KINEMATIK\n');
fprintf('Spindeldiameter d                  = %.4f mm\n', ...
    nominalScrewDiameter);
fprintf('Pitch p                            = %.4f mm\n', threadPitch);
fprintf('Antal gevindstarter n              = %d\n', ...
    numberOfThreadStarts);
fprintf('Lead l=p*n                         = %.4f mm/omdr.\n', lead);
fprintf('Gevinddybde                        = %.4f mm\n', threadDepth);
if isfinite(threadWidth)
    fprintf('Gevindbredde                       = %.4f mm\n', threadWidth);
end
fprintf('Roddiameter d_r                    = %.4f mm\n', rootDiameter);
fprintf('Middeldiameter d_m                 = %.4f mm\n', ...
    threadMeanDiameter);
fprintf('tan(lambda)                        = %.6f\n', ...
    results.tanLeadAngle);
fprintf('Stigningsvinkel lambda             = %.4f deg\n', ...
    results.leadAngleDeg);
fprintf('Lineær hastighed v                 = %.4f mm/s\n', ...
    linearVelocity);
fprintf('Omdrejningsfrekvens                = %.4f omdr./s\n', ...
    rotationalFrequency);
fprintf('Omdrejningstal                     = %.3f rpm\n', ...
    rotationalSpeedRpm);
fprintf('Vinkelhastighed omega              = %.4f rad/s\n', ...
    angularVelocity);

fprintf('\nLAST OG MOMENTER\n');
fprintf('Aksial last F                      = %.3f kN\n', ...
    axialLoad/1e3);
fprintf('Gevindfriktion f                   = %.4f\n', ...
    threadFrictionCoefficient);
fprintf('Brystfriktion f_c                  = %.4f\n', ...
    collarFrictionUsed);
fprintf('Friktionsdiameter d_c              = %.4f mm\n', ...
    collarMeanDiameter);
fprintf('Ideelt moment T_0                  = %.4f N*m\n', ...
    results.idealTorque/1e3);
fprintf('Gevindmoment ved løft T_R          = %.4f N*m\n', ...
    results.threadRaisingTorque/1e3);
fprintf('Gevindmoment ved sænkning T_L      = %.4f N*m\n', ...
    results.threadLoweringTorque/1e3);
fprintf('Brystmoment T_c                    = %.4f N*m\n', ...
    results.collarTorque/1e3);
fprintf('Samlet løftemoment T_R,total       = %.4f N*m\n', ...
    results.totalRaisingTorque/1e3);
fprintf('Samlet sænkemoment T_L,total       = %.4f N*m\n', ...
    results.totalLoweringTorque/1e3);

fprintf('\nEFFEKT OG VIRKNINGSGRAD\n');
fprintf('Ideel nyttig effekt F*v            = %.4f kW\n', ...
    results.idealLinearPower/1e3);
fprintf('Effekt ved løft                    = %.4f kW\n', ...
    results.raisingPower/1e3);
fprintf('Signeret effekt ved sænkning       = %.4f kW\n', ...
    results.loweringPower/1e3);
fprintf('Virkningsgrad ved løft e_R         = %.6f = %.2f %%\n', ...
    results.raisingEfficiency, 100*results.raisingEfficiency);
if isfinite(results.courseLoweringEfficiency)
    fprintf('Kursusets sænkevirkningsgrad       = %.6f = %.2f %%\n', ...
        results.courseLoweringEfficiency, ...
        100*results.courseLoweringEfficiency);
else
    fprintf(['Kursusets sænkevirkningsgrad       = ikke defineret ', ...
        'for T_L,total<=0\n']);
end

%% AUTOMATIC CHECKS
if results.threadSelfLocking
    fprintf('OK: Gevindet er selvlåsende, fordi f>tan(lambda).\n');
elseif results.atSelfLockingBoundary
    fprintf('ADVARSEL: Gevindet ligger på selvlåsningsgrænsen.\n');
else
    fprintf('ADVARSEL: Selve gevindet er ikke selvlåsende.\n');
end

if results.totalLoweringTorque > results.torqueZeroTolerance
    fprintf(['OK: Samlet T_L,total er positivt; der kræves et ', ...
        'aktivt sænkemoment.\n']);
elseif abs(results.totalLoweringTorque) <= results.torqueZeroTolerance
    fprintf('ADVARSEL: Samlet sænkemoment er cirka nul.\n');
else
    fprintf(['ADVARSEL: Lasten kan drive spindlen i ', ...
        'sænkeretningen.\n']);
end

if requireThreadSelfLocking && ~results.threadSelfLocking
    fprintf('IKKE OK: Kravet om selvlåsende gevind er ikke opfyldt.\n');
else
    fprintf('OK: Det valgte krav til selvlåsning er opfyldt.\n');
end

if results.raisingEfficiency+1e-12 >= minimumRaisingEfficiency
    fprintf('OK: Kravet til løftevirkningsgrad er opfyldt.\n');
else
    fprintf('IKKE OK: Kravet til løftevirkningsgrad er ikke opfyldt.\n');
end

if results.raisingEfficiency > 0 && ...
        results.raisingEfficiency <= 1+1e-12
    fprintf('OK: Løftevirkningsgraden ligger mellem 0 og 1.\n');
else
    fprintf('IKKE OK: Løftevirkningsgraden er ikke fysisk gyldig.\n');
end

if results.powerConsistencyError <= ...
        1e-9*max(1,abs(results.idealLinearPower))
    fprintf('OK: Effektkontrollen F*v=T_0*omega stemmer.\n');
else
    fprintf('IKKE OK: Effektkontrollen stemmer ikke.\n');
end

%% PLOTS
if makeFrictionSweepPlot
    frictionValues = linspace(0, frictionSweepMaximum, 250);
    raisingTorqueSweep = zeros(size(frictionValues));
    loweringTorqueSweep = zeros(size(frictionValues));

    for i = 1:numel(frictionValues)
        sweep = calculateB4(axialLoad, nominalScrewDiameter, ...
            threadPitch, numberOfThreadStarts, ...
            threadMeanDiameter, rootDiameter, frictionValues(i), ...
            collarFrictionUsed, collarMeanDiameter, ...
            linearVelocity, angularVelocity);
        raisingTorqueSweep(i) = sweep.totalRaisingTorque/1e3;
        loweringTorqueSweep(i) = sweep.totalLoweringTorque/1e3;
    end

    figure('Name','B4 - Moment og gevindfriktion');
    plot(frictionValues, raisingTorqueSweep, 'LineWidth',1.5);
    hold on;
    plot(frictionValues, loweringTorqueSweep, 'LineWidth',1.5);
    yline(0,':','T=0');
    xline(results.tanLeadAngle,'--','f=tan(lambda)');
    scatter(threadFrictionCoefficient, ...
        results.totalRaisingTorque/1e3,45);
    scatter(threadFrictionCoefficient, ...
        results.totalLoweringTorque/1e3,45);
    xlabel('Gevindfriktionskoefficient f [-]');
    ylabel('Samlet moment [N*m]');
    title('Løfte- og sænkemoment som funktion af gevindfriktion');
    legend({'T_{R,total}','T_{L,total}','T=0', ...
        'Selvlåsningsgrænse','Aktuelt løft','Aktuel sænkning'}, ...
        'Location','best');
    grid on;
    hold off;
end

%% PHYSICAL CONCLUSION
fprintf('\nFYSISK KONKLUSION\n');
fprintf(['Spindlen omsætter %.3f omdr./s til %.3f mm/s og ', ...
    'løfter %.3f kN.\n'], rotationalFrequency, ...
    linearVelocity, axialLoad/1e3);
fprintf(['Det kræver %.3f N*m og %.3f kW ved den valgte ', ...
    'hastighed.\n'], results.totalRaisingTorque/1e3, ...
    results.raisingPower/1e3);

if results.threadSelfLocking
    fprintf('Selve gevindet er selvlåsende efter kursuskriteriet.\n');
elseif results.totalLoweringTorque > 0
    fprintf(['Gevindet er ikke selvlåsende, men brystfriktionen ', ...
        'gør det samlede sænkemoment positivt.\n']);
else
    fprintf('Systemet kan blive drevet af lasten ved sænkning.\n');
end
fprintf(['Resultatet afhænger især af f, f_c og d_c. ', ...
    'Styrke og knæk er ikke kontrolleret.\n']);

%% OPTIONAL TEST CASES
if runCourseValidationTests
    courseTestResults = runB4CourseTests();
    results.courseTestResults = courseTestResults;
    fprintf('\nKONTROL MOD OPGAVE 8-4, 8-9 OG GRÆNSETILFÆLDE\n');
    disp(courseTestResults);
    if all(courseTestResults.Status == "OK")
        fprintf('OK: Alle automatiske B4-tests er bestået.\n');
    else
        fprintf('IKKE OK: Mindst én automatisk B4-test fejler.\n');
    end
end

%% LOCAL FUNCTIONS
function r = calculateB4(F,d,p,n,dm,dr,f,fc,dc,v,omega)
    lead = p*n;
    tanLambda = lead/(pi*dm);
    denominatorRaise = pi*dm-f*lead;
    denominatorLower = pi*dm+f*lead;

    assert(denominatorRaise > 0 && denominatorLower > 0, ...
        'Ugyldig nævner i momentformlen.');

    TR = F*dm/2*(lead+pi*f*dm)/denominatorRaise;
    TL = F*dm/2*(pi*f*dm-lead)/denominatorLower;
    Tc = F*fc*dc/2;
    TRtotal = TR+Tc;
    TLtotal = TL+Tc;
    T0 = F*lead/(2*pi);

    if TRtotal > 0
        etaRaise = T0/TRtotal;
    else
        etaRaise = NaN;
    end
    if TLtotal > 0
        etaLowerCourse = T0/TLtotal;
    else
        etaLowerCourse = NaN;
    end

    selfLockTolerance = 1e-12*max([1,abs(f),abs(tanLambda)]);
    torqueZeroTolerance = ...
        1e-12*max([1,abs(TRtotal),abs(TLtotal)]);

    r = struct();
    r.axialLoad = F;
    r.nominalDiameter = d;
    r.threadPitch = p;
    r.numberOfThreadStarts = n;
    r.threadMeanDiameter = dm;
    r.rootDiameter = dr;
    r.lead = lead;
    r.tanLeadAngle = tanLambda;
    r.leadAngleDeg = atand(tanLambda);
    r.threadRaisingTorque = TR;
    r.threadLoweringTorque = TL;
    r.collarTorque = Tc;
    r.totalRaisingTorque = TRtotal;
    r.totalLoweringTorque = TLtotal;
    r.idealTorque = T0;
    r.raisingPower = TRtotal/1e3*omega;
    r.loweringPower = TLtotal/1e3*omega;
    r.idealPower = T0/1e3*omega;
    r.raisingEfficiency = etaRaise;
    r.courseLoweringEfficiency = etaLowerCourse;
    r.threadSelfLocking = f > tanLambda+selfLockTolerance;
    r.atSelfLockingBoundary = ...
        abs(f-tanLambda) <= selfLockTolerance;
    r.torqueZeroTolerance = torqueZeroTolerance;
    r.linearVelocity = v;
    r.angularVelocity = omega;
end

function testTable = runB4CourseTests()
    % Kursusopgave 8-4.
    c84 = calculateB4(5e3,25,5,1,22.5,20,0.09,0.06,45,0,0);

    % Kursusopgave 8-9.
    omega89 = 2*pi*48/12;
    c89 = calculateB4(10e3,40,6,2,37,34,0.10,0.15,60,48,omega89);

    % Håndkontrol uden friktion.
    hand = calculateB4(2e3,20,4,1,18,16,0,0,0,0,0);

    % Selvlåsningsgrænse.
    boundary = calculateB4(2e3,20,4,1,18,16, ...
        hand.tanLeadAngle,0,0,0,0);

    testName = [ ...
        "8-4: d_m [mm]";
        "8-4: T_R [N*m]";
        "8-4: T_L [N*m]";
        "8-4: T_c [N*m]";
        "8-4: T_R,total [N*m]";
        "8-4: T_L,total [N*m]";
        "8-4: e_løft";
        "8-4: e_sænk";
        "8-9: omega [rad/s]";
        "8-9: T_R [N*m]";
        "8-9: T_L [N*m]";
        "8-9: T_c [N*m]";
        "8-9: T_R,total [N*m]";
        "8-9: P_løft [kW]";
        "Håndkontrol: T_R=T_0";
        "Håndkontrol: e_R=1";
        "Grænse: T_L=0 ved f=tan(lambda)"];

    calculated = [ ...
        22.5;
        c84.threadRaisingTorque/1e3;
        c84.threadLoweringTorque/1e3;
        c84.collarTorque/1e3;
        c84.totalRaisingTorque/1e3;
        c84.totalLoweringTorque/1e3;
        c84.raisingEfficiency;
        c84.courseLoweringEfficiency;
        omega89;
        c89.threadRaisingTorque/1e3;
        c89.threadLoweringTorque/1e3;
        c89.collarTorque/1e3;
        c89.totalRaisingTorque/1e3;
        c89.raisingPower/1e3;
        hand.threadRaisingTorque-hand.idealTorque;
        hand.raisingEfficiency;
        boundary.threadLoweringTorque];

    expected = [ ...
        22.5; 9.099; 1.077; 6.750; 15.849; 7.827; ...
        0.251; 0.508; 25.133; 37.991; -0.592; 45.000; ...
        82.991; 2.086; 0; 1; 0];

    relativeTolerance = [ ...
        repmat(2e-3,14,1); 0; 1e-12; 0];
    absoluteTolerance = [ ...
        zeros(14,1); 1e-9; 1e-12; 1e-9];

    absoluteError = abs(calculated-expected);
    allowedError = max(absoluteTolerance, ...
        relativeTolerance.*abs(expected));
    relativeError = absoluteError./max(abs(expected),1);

    status = repmat("OK",size(testName));
    status(absoluteError > allowedError) = "IKKE OK";

    testTable = table(testName,calculated,expected, ...
        100*relativeError,allowedError,status, ...
        'VariableNames',{'Test','Calculated','CourseOrExpected', ...
        'RelativeError_percent','AllowedAbsoluteError','Status'});
end
