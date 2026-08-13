%% B1 - BOLTENS OG EMNERNES STIVHED
% Use this script when:
%   - en bolt/møtrik-samling modelleres som elastiske fjedre,
%   - boltens skaft- og gevinddel ligger i serie,
%   - emnernes trykkegler skal opdeles ved materialeskift og midterplan,
%   - lastfordelingskoefficienten C = k_b/(k_b + k_m) ønskes.
%
% Do not use this script when:
%   - der skal kontrolleres flydning, separation, udmattelse eller tilspænding
%     (brug B2/B3),
%   - samlingen har flere bolte med excentrisk last uden separat lastmodel,
%   - kontaktfladen/trykkeglen er begrænset af frie kanter uden en korrigeret model.
%
% Kursusgrundlag:
%   - Forelæsning "Spindler og bolte", ligning (8-16) til (8-22).
%   - Kursusopgaver 8-11 og 8-20.
%   - Eksempeleksamen, problem 2 (ukendt E-modul).

clear; clc; close all;

%% ASSUMPTIONS AND MANUAL INPUT
% Enheder: N, mm og MPa (= N/mm^2).
% Bolten og emnerne antages lineært elastiske.
% Trykkeglen går fra hver anlægsflade til samlingens geometriske midterplan.
% Ved materialeskift fortsætter den samme geometriske kegle.
% Alle delstivheder i bolten er i serie. Alle keglesegmenter er i serie.
% Gevindets trækspændingsareal A_t samt anlægsdiametre skal slås op manuelt.
% Lagene angives fra overside (bolthoved) mod underside (møtrik).

%% INPUT
analysisMode = "direct";             % [-] "direct" eller "solveUnknownE"

% --- Bolt ---
boltNominalDiameter = 10;            % [mm] Nominel skaftdiameter d
boltTensileStressArea = 58.0;        % [mm^2] Trækspændingsareal A_t, tabel 8-1
boltElasticModulus = 207e3;          % [MPa] Boltens E-modul
boltLength = 70;                     % [mm] Valgt standard boltlængde L

threadLengthMode = "manual";         % [-] "manual" eller "courseEq8_14"
boltTotalThreadLengthManual = 26;    % [mm] Total gevindlængde L_T

% --- Sammenspændte emner, fra top mod bund ---
memberThickness = [10, 30, 20];      % [mm] Lagtykkelser
memberElasticModulus = [71e3, 207e3, 71e3]; % [MPa] E-modul for hvert lag

bearingDiameterTop = 16;             % [mm] Anlægsdiameter D ved bolthoved
bearingDiameterBottom = 16;          % [mm] Anlægsdiameter D ved møtrik
coneHalfAngleDeg = 30;               % [deg] Trykkeglens halve vinkel alpha
useRoundedCourseEquation820 = true;  % [-] Brug 0.5774 og 1.155 ved alpha=30°

% --- Omvendt løsning: ukendt E-modul ---
unknownMemberIndex = 2;              % [-] Lagnummer med ukendt E
targetMemberStiffness = 5.0e6;       % [N/mm] Krævet samlet emnestivhed k_m
unknownEBracket = [1e3, 500e3];      % [MPa] Søgeinterval til fzero

% --- Visning og selvtest ---
makeCompressionConePlot = true;      % [-] Plot af den anvendte trykkegle
runCourseValidationTests = true;     % [-] Kontrol mod 8-11, 8-20 og eksamen

%% UNIT CHECK AND VALIDATION
validAnalysisModes = ["direct", "solveUnknownE"];
assert(any(analysisMode == validAnalysisModes), ...
    'analysisMode skal være "direct" eller "solveUnknownE".');

assert(isscalar(boltNominalDiameter) && boltNominalDiameter > 0, ...
    'Boltens diameter skal være positiv.');
assert(isscalar(boltTensileStressArea) && boltTensileStressArea > 0, ...
    'A_t skal være positiv og slås op for det valgte gevind.');
assert(isscalar(boltElasticModulus) && boltElasticModulus > 0, ...
    'Boltens E-modul skal være positivt.');
assert(isscalar(boltLength) && boltLength > 0, ...
    'Boltlængden skal være positiv.');

memberThickness = memberThickness(:).';
memberElasticModulus = memberElasticModulus(:).';
assert(~isempty(memberThickness) && all(isfinite(memberThickness)) && ...
    all(memberThickness > 0), 'Alle lagtykkelser skal være positive.');
assert(numel(memberThickness) == numel(memberElasticModulus), ...
    'memberThickness og memberElasticModulus skal have samme længde.');

gripLength = sum(memberThickness);   % [mm] Klemmelængde l
assert(boltLength >= gripLength, ...
    'Boltlængden L skal mindst være lig klemmelængden l.');

assert(isscalar(bearingDiameterTop) && ...
    bearingDiameterTop > boltNominalDiameter, ...
    'Øvre anlægsdiameter skal være større end boltdiameteren.');
assert(isscalar(bearingDiameterBottom) && ...
    bearingDiameterBottom > boltNominalDiameter, ...
    'Nedre anlægsdiameter skal være større end boltdiameteren.');
assert(isscalar(coneHalfAngleDeg) && coneHalfAngleDeg > 0 && ...
    coneHalfAngleDeg < 90, 'Keglevinklen skal ligge mellem 0 og 90 grader.');

switch threadLengthMode
    case "manual"
        boltTotalThreadLength = boltTotalThreadLengthManual;

    case "courseEq8_14"
        % Kursusregel for metrisk gevindlængde.
        if boltLength <= 125 && boltNominalDiameter < 48
            boltTotalThreadLength = 2*boltNominalDiameter + 6;
        elseif boltLength > 125 && boltLength <= 200
            boltTotalThreadLength = 2*boltNominalDiameter + 12;
        elseif boltLength > 200
            boltTotalThreadLength = 2*boltNominalDiameter + 25;
        else
            error(['Kursusregel (8-14) dækker ikke denne kombination. ', ...
                'Vælg threadLengthMode="manual" og indtast L_T.']);
        end

    otherwise
        error('Ukendt threadLengthMode.');
end

assert(isscalar(boltTotalThreadLength) && boltTotalThreadLength >= 0, ...
    'Total gevindlængde L_T skal være ikke-negativ.');
assert(boltTotalThreadLength <= boltLength, ...
    'L_T kan ikke være større end boltlængden L.');

if analysisMode == "direct"
    assert(all(isfinite(memberElasticModulus)) && ...
        all(memberElasticModulus > 0), ...
        'Alle E-moduler skal være positive i direct-mode.');
else
    assert(isscalar(unknownMemberIndex) && ...
        unknownMemberIndex == floor(unknownMemberIndex) && ...
        unknownMemberIndex >= 1 && ...
        unknownMemberIndex <= numel(memberElasticModulus), ...
        'unknownMemberIndex er ugyldigt.');
    assert(isnan(memberElasticModulus(unknownMemberIndex)), ...
        'Sæt det ukendte E-modul til NaN i memberElasticModulus.');
    knownE = memberElasticModulus;
    knownE(unknownMemberIndex) = [];
    assert(all(isfinite(knownE)) && all(knownE > 0), ...
        'Alle kendte E-moduler skal være positive.');
    assert(isscalar(targetMemberStiffness) && targetMemberStiffness > 0, ...
        'targetMemberStiffness skal være positiv.');
    assert(numel(unknownEBracket) == 2 && ...
        all(isfinite(unknownEBracket)) && ...
        all(unknownEBracket > 0) && ...
        unknownEBracket(1) < unknownEBracket(2), ...
        'unknownEBracket skal være [E_min E_max] med positive værdier.');
end

%% CALCULATION
memberElasticModulusUsed = memberElasticModulus;
solvedUnknownE = NaN;

if analysisMode == "solveUnknownE"
    residual = @(Etrial) memberStiffnessResidual( ...
        Etrial, unknownMemberIndex, memberElasticModulus, ...
        memberThickness, boltNominalDiameter, ...
        bearingDiameterTop, bearingDiameterBottom, ...
        coneHalfAngleDeg, useRoundedCourseEquation820, ...
        targetMemberStiffness);

    residualAtLower = residual(unknownEBracket(1));
    residualAtUpper = residual(unknownEBracket(2));
    assert(residualAtLower * residualAtUpper <= 0, ...
        ['fzero-intervallet omslutter ikke en løsning. ', ...
        'Udvid unknownEBracket eller kontrollér mål-stivheden.']);

    fzeroOptions = optimset('TolX', 1e-8, 'Display', 'off');
    solvedUnknownE = fzero(residual, unknownEBracket, fzeroOptions);
    memberElasticModulusUsed(unknownMemberIndex) = solvedUnknownE;
end

results = calculateB1Case( ...
    boltNominalDiameter, boltTensileStressArea, boltElasticModulus, ...
    boltLength, boltTotalThreadLength, memberThickness, ...
    memberElasticModulusUsed, bearingDiameterTop, ...
    bearingDiameterBottom, coneHalfAngleDeg, ...
    useRoundedCourseEquation820);

results.analysisMode = analysisMode;
results.gripLength = gripLength;
results.boltTotalThreadLength = boltTotalThreadLength;
results.memberElasticModulusUsed = memberElasticModulusUsed;
results.solvedUnknownE = solvedUnknownE;

% Samme-materiale-kontrol med kursusligning (8-21), når den er anvendelig.
sameMaterialCase = max(abs(memberElasticModulusUsed - ...
    memberElasticModulusUsed(1))) <= ...
    1e-12*max(1, abs(memberElasticModulusUsed(1)));
sameBearingDiameter = abs(bearingDiameterTop - bearingDiameterBottom) <= ...
    1e-12*max(1, bearingDiameterTop);

if sameMaterialCase && sameBearingDiameter
    results.memberStiffnessEq821 = memberStiffnessEquation821( ...
        memberElasticModulusUsed(1), boltNominalDiameter, ...
        bearingDiameterTop, gripLength, coneHalfAngleDeg);
    results.eq821RelativeDifference = abs( ...
        results.memberStiffness - results.memberStiffnessEq821) / ...
        results.memberStiffnessEq821;
else
    results.memberStiffnessEq821 = NaN;
    results.eq821RelativeDifference = NaN;
end

%% RESULTS
fprintf('\n============================================================\n');
fprintf('B1 - BOLTENS OG EMNERNES STIVHED\n');
fprintf('============================================================\n');
fprintf('Klemmelængde l                 = %.3f mm\n', gripLength);
fprintf('Gevindfri længde i greb l_d    = %.3f mm\n', ...
    results.bolt.unthreadedLengthInGrip);
fprintf('Gevindlængde i greb l_t        = %.3f mm\n', ...
    results.bolt.threadedLengthInGrip);
fprintf('Skaftareal A_d                  = %.3f mm^2\n', ...
    results.bolt.shankArea);
fprintf('Trækspændingsareal A_t          = %.3f mm^2\n', ...
    boltTensileStressArea);

fprintf('\nBoltstivhed k_b                 = %.6g N/mm\n', ...
    results.boltStiffness);
fprintf('                                  %.6g N/m\n', ...
    results.boltStiffness*1e3);
fprintf('Emnestivhed k_m                 = %.6g N/mm\n', ...
    results.memberStiffness);
fprintf('                                  %.6g N/m\n', ...
    results.memberStiffness*1e3);
fprintf('Lastfordelingskoefficient C     = %.6f\n', ...
    results.loadFractionC);
fprintf('Andel af ydre aksiallast i bolt = %.2f %%\n', ...
    100*results.loadFractionC);

if analysisMode == "solveUnknownE"
    fprintf('\nLøst E-modul for lag %d          = %.3f MPa = %.3f GPa\n', ...
        unknownMemberIndex, solvedUnknownE, solvedUnknownE/1e3);
    fprintf('Kontrol: beregnet k_m            = %.6g N/mm\n', ...
        results.memberStiffness);
    fprintf('Mål: targetMemberStiffness       = %.6g N/mm\n', ...
        targetMemberStiffness);
end

fprintf('\nDelstivheder for trykkeglen:\n');
disp(results.memberSegments);

if ~isnan(results.memberStiffnessEq821)
    fprintf('Kontrol med ligning (8-21): k_m  = %.6g N/mm\n', ...
        results.memberStiffnessEq821);
    fprintf('Relativ forskel                  = %.4f %%\n', ...
        100*results.eq821RelativeDifference);
end

%% AUTOMATIC CHECKS
if results.boltStiffness > 0 && results.memberStiffness > 0
    fprintf('OK: Alle beregnede stivheder er positive.\n');
else
    fprintf('IKKE OK: Mindst én stivhed er ikke positiv.\n');
end

if results.loadFractionC > 0 && results.loadFractionC < 1
    fprintf('OK: C ligger fysisk korrekt mellem 0 og 1.\n');
else
    fprintf('IKKE OK: C ligger ikke mellem 0 og 1.\n');
end

segmentThicknessSum = sum(results.memberSegments.Thickness_mm);
if abs(segmentThicknessSum - gripLength) <= 1e-10*max(1, gripLength)
    fprintf('OK: Keglesegmenterne dækker hele klemmelængden.\n');
else
    fprintf(['IKKE OK: Keglesegmenternes samlede tykkelse svarer ikke ', ...
        'til klemmelængden.\n']);
end

if ~isnan(results.memberStiffnessEq821)
    if results.eq821RelativeDifference <= 2e-3
        fprintf('OK: Stykvis model stemmer med kursusligning (8-21).\n');
    else
        fprintf(['ADVARSEL: Stykvis model afviger mere end 0,2 %% fra ', ...
            'ligning (8-21). Kontrollér afrunding og geometri.\n']);
    end
end

%% PLOTS
if makeCompressionConePlot
    plotCompressionConeGeometry( ...
        memberThickness, boltNominalDiameter, ...
        bearingDiameterTop, bearingDiameterBottom, ...
        coneHalfAngleDeg);
end

%% PHYSICAL CONCLUSION
fprintf('\nFYSISK KONKLUSION\n');
if results.memberStiffness > results.boltStiffness
    fprintf(['Emnerne er stivere end bolten. Derfor går en relativt ', ...
        'mindre del af en senere ydre aksiallast i bolten.\n']);
else
    fprintf(['Bolten er mindst lige så stiv som emnerne. Derfor går en ', ...
        'relativt stor del af en senere ydre aksiallast i bolten.\n']);
end
fprintf(['B1 bestemmer kun stivheder og C. Flydning, separation, ', ...
    'forspænding og tilspændingsmoment skal kontrolleres i B2/B3.\n']);
fprintf(['Resultatet afhænger især af A_t, anlægsdiametrene og den ', ...
    'antagne 30-graders trykkegle.\n']);

%% OPTIONAL TEST CASES
if runCourseValidationTests
    courseTestResults = runB1CourseTests();
    results.courseTestResults = courseTestResults;

    fprintf('\nKONTROL MOD KURSUSOPGAVER\n');
    disp(courseTestResults);

    if all(courseTestResults.Status == "OK")
        fprintf('OK: Alle kursustests er inden for den valgte tolerance.\n');
    else
        fprintf(['IKKE OK: Mindst én kursustest afviger. Kontrollér ', ...
            'formler, afrunding og input.\n']);
    end
end

%% LOCAL FUNCTIONS
function results = calculateB1Case( ...
    d, At, Eb, boltLength, totalThreadLength, ...
    memberThickness, memberE, Dtop, Dbottom, alphaDeg, ...
    useRoundedEq820)

    gripLength = sum(memberThickness);

    bolt = calculateBoltStiffness( ...
        d, At, Eb, boltLength, totalThreadLength, gripLength);

    [km, memberSegments] = calculateMemberStiffness( ...
        memberThickness, memberE, d, Dtop, Dbottom, ...
        alphaDeg, useRoundedEq820);

    results = struct();
    results.bolt = bolt;
    results.boltStiffness = bolt.stiffness;
    results.memberStiffness = km;
    results.loadFractionC = bolt.stiffness/(bolt.stiffness + km);
    results.memberSegments = memberSegments;
end

function bolt = calculateBoltStiffness( ...
    d, At, E, boltLength, totalThreadLength, gripLength)

    Ad = pi*d^2/4;
    totalUnthreadedLength = boltLength - totalThreadLength;

    % Kun den del, der ligger inden for grebet, bidrager til modellen.
    ld = min(max(totalUnthreadedLength, 0), gripLength);
    lt = gripLength - ld;

    complianceShank = ld/(Ad*E);
    complianceThread = lt/(At*E);
    totalCompliance = complianceShank + complianceThread;

    assert(totalCompliance > 0, ...
        'Boltens samlede compliance skal være positiv.');

    if ld > 0
        kShank = Ad*E/ld;
    else
        kShank = Inf;
    end

    if lt > 0
        kThread = At*E/lt;
    else
        kThread = Inf;
    end

    bolt = struct();
    bolt.shankArea = Ad;
    bolt.unthreadedLengthInGrip = ld;
    bolt.threadedLengthInGrip = lt;
    bolt.shankStiffness = kShank;
    bolt.threadStiffness = kThread;
    bolt.stiffness = 1/totalCompliance;
end

function [km, segmentTable] = calculateMemberStiffness( ...
    thickness, E, d, Dtop, Dbottom, alphaDeg, useRoundedEq820)

    thickness = thickness(:).';
    E = E(:).';
    nLayers = numel(thickness);
    totalThickness = sum(thickness);
    middlePlane = totalThickness/2;
    layerEdges = [0, cumsum(thickness)];

    side = strings(0,1);
    layer = zeros(0,1);
    segmentThickness = zeros(0,1);
    elasticModulus = zeros(0,1);
    startDiameter = zeros(0,1);
    endDiameter = zeros(0,1);
    stiffness = zeros(0,1);

    % Øvre trykkegle: fra bolthoved mod midterplanet.
    currentDiameter = Dtop;
    for i = 1:nLayers
        segmentStart = max(layerEdges(i), 0);
        segmentEnd = min(layerEdges(i+1), middlePlane);
        tSegment = segmentEnd - segmentStart;

        if tSegment > 1e-12
            kSegment = compressionConeStiffness( ...
                E(i), d, currentDiameter, tSegment, ...
                alphaDeg, useRoundedEq820);
            nextDiameter = currentDiameter + ...
                2*tand(alphaDeg)*tSegment;

            side(end+1,1) = "Top";
            layer(end+1,1) = i;
            segmentThickness(end+1,1) = tSegment;
            elasticModulus(end+1,1) = E(i);
            startDiameter(end+1,1) = currentDiameter;
            endDiameter(end+1,1) = nextDiameter;
            stiffness(end+1,1) = kSegment;

            currentDiameter = nextDiameter;
        end

        if layerEdges(i+1) >= middlePlane
            break;
        end
    end

    % Nedre trykkegle: fra møtrik mod midterplanet.
    currentDiameter = Dbottom;
    for i = nLayers:-1:1
        segmentStart = max(layerEdges(i), middlePlane);
        segmentEnd = min(layerEdges(i+1), totalThickness);
        tSegment = segmentEnd - segmentStart;

        if tSegment > 1e-12
            kSegment = compressionConeStiffness( ...
                E(i), d, currentDiameter, tSegment, ...
                alphaDeg, useRoundedEq820);
            nextDiameter = currentDiameter + ...
                2*tand(alphaDeg)*tSegment;

            side(end+1,1) = "Bund";
            layer(end+1,1) = i;
            segmentThickness(end+1,1) = tSegment;
            elasticModulus(end+1,1) = E(i);
            startDiameter(end+1,1) = currentDiameter;
            endDiameter(end+1,1) = nextDiameter;
            stiffness(end+1,1) = kSegment;

            currentDiameter = nextDiameter;
        end

        if layerEdges(i) <= middlePlane
            break;
        end
    end

    assert(~isempty(stiffness), ...
        'Der blev ikke dannet nogen trykkeglesegmenter.');
    assert(all(stiffness > 0) && all(isfinite(stiffness)), ...
        'Alle keglesegmenters stivheder skal være positive og endelige.');

    km = 1/sum(1./stiffness);

    segmentTable = table( ...
        side, layer, segmentThickness, elasticModulus, ...
        startDiameter, endDiameter, stiffness, ...
        'VariableNames', { ...
        'Side', 'Layer', 'Thickness_mm', 'E_MPa', ...
        'Dstart_mm', 'Dend_mm', 'Stiffness_N_per_mm'});
end

function k = compressionConeStiffness( ...
    E, d, D, t, alphaDeg, useRoundedEq820)

    assert(E > 0 && d > 0 && D > d && t > 0, ...
        'Ugyldige input til trykkeglestivheden.');

    if useRoundedEq820 && abs(alphaDeg - 30) <= 1e-12
        % Kursusligning (8-20) med de viste afrundede konstanter.
        numeratorTangent = 0.5774;
        axialDiameterFactor = 1.155;
    else
        % Generel kursusligning (8-19).
        numeratorTangent = tand(alphaDeg);
        axialDiameterFactor = 2*tand(alphaDeg);
    end

    logArgument = ...
        ((axialDiameterFactor*t + D - d)*(D + d)) / ...
        ((axialDiameterFactor*t + D + d)*(D - d));

    assert(logArgument > 1 && isfinite(logArgument), ...
        ['Logaritmens argument er ikke fysisk gyldigt. ', ...
        'Kontrollér D>d, t og keglevinklen.']);

    k = pi*E*d*numeratorTangent/log(logArgument);
end

function residual = memberStiffnessResidual( ...
    Etrial, unknownIndex, memberE, thickness, d, ...
    Dtop, Dbottom, alphaDeg, useRoundedEq820, targetKm)

    trialE = memberE;
    trialE(unknownIndex) = Etrial;
    [km, ~] = calculateMemberStiffness( ...
        thickness, trialE, d, Dtop, Dbottom, ...
        alphaDeg, useRoundedEq820);
    residual = km - targetKm;
end

function km = memberStiffnessEquation821(E, d, Dw, l, alphaDeg)
    tanAlpha = tand(alphaDeg);
    logArgument = ...
        ((l*tanAlpha + Dw - d)*(Dw + d)) / ...
        ((l*tanAlpha + Dw + d)*(Dw - d));

    assert(logArgument > 1, ...
        'Ugyldig geometri i ligning (8-21).');

    km = pi*E*d*tanAlpha/(2*log(logArgument));
end

function plotCompressionConeGeometry( ...
    thickness, d, Dtop, Dbottom, alphaDeg)

    totalThickness = sum(thickness);
    middlePlane = totalThickness/2;
    layerEdges = [0, cumsum(thickness)];

    depthTop = linspace(0, middlePlane, 150);
    diameterTop = Dtop + 2*tand(alphaDeg)*depthTop;

    depthBottom = linspace(totalThickness, middlePlane, 150);
    diameterBottom = Dbottom + ...
        2*tand(alphaDeg)*(totalThickness - depthBottom);

    figure('Name', 'B1 - Trykkeglegeometri');
    hTop = plot(diameterTop, depthTop, 'LineWidth', 1.5);
    hold on;
    hBottom = plot(diameterBottom, depthBottom, 'LineWidth', 1.5);
    xline(d, '--', 'Boltdiameter d');

    for i = 1:numel(layerEdges)
        yline(layerEdges(i), ':');
    end
    yline(middlePlane, '--', 'Midterplan');

    set(gca, 'YDir', 'reverse');
    xlabel('Trykkeglens diameter D(y) [mm]');
    ylabel('Dybde fra oversiden [mm]');
    title('Kontrol af trykkeglens opdeling');
    legend([hTop, hBottom], {'Fra bolthoved', 'Fra møtrik'}, ...
        'Location', 'best');
    grid on;
    hold off;
end

function testTable = runB1CourseTests()
    tolerance = 2e-3; % 0,2 % pga. afrundede kursusfacitter.

    testName = strings(5,1);
    calculated = zeros(5,1);
    expected = zeros(5,1);
    unit = strings(5,1);

    % Kursusopgave 8-11.
    case811 = calculateB1Case( ...
        14, 115, 210e3, 45, 34, ...
        [15, 15], [210e3, 210e3], ...
        21, 21, 30, true);

    testName(1) = "8-11: k_b";
    calculated(1) = case811.boltStiffness;
    expected(1) = 8.873e5; % 8.873e8 N/m
    unit(1) = "N/mm";

    testName(2) = "8-11: k_m";
    calculated(2) = case811.memberStiffness;
    expected(2) = 3.161e6; % Kursusfacit
    unit(2) = "N/mm";

    % Kursusopgave 8-20.
    case820 = calculateB1Case( ...
        10, 58, 207e3, 70, 26, ...
        [10, 30, 20], [71e3, 207e3, 71e3], ...
        16, 16, 30, true);

    testName(3) = "8-20: k_b";
    calculated(3) = case820.boltStiffness;
    expected(3) = 2.476e5; % 2.476e8 N/m
    unit(3) = "N/mm";

    testName(4) = "8-20: k_m";
    calculated(4) = case820.memberStiffness;
    expected(4) = 7.097e5; % 7.097e8 N/m
    unit(4) = "N/mm";

    % Eksempeleksamen problem 2: find E_2.
    examThickness = [30, 30];
    examE = [200e3, NaN];
    examTargetKm = 5e6;
    examResidual = @(E2) memberStiffnessResidual( ...
        E2, 2, examE, examThickness, 24, ...
        36, 36, 30, true, examTargetKm);
    solvedE2 = fzero(examResidual, [1e3, 500e3]);

    testName(5) = "Eksamen problem 2: E_2";
    calculated(5) = solvedE2;
    expected(5) = 215e3; % 215 GPa
    unit(5) = "MPa";

    relativeError = abs(calculated - expected)./abs(expected);
    status = repmat("OK", size(testName));
    status(relativeError > tolerance) = "IKKE OK";

    testTable = table( ...
        testName, calculated, expected, unit, ...
        100*relativeError, status, ...
        'VariableNames', { ...
        'Test', 'Calculated', 'CourseValue', 'Unit', ...
        'RelativeError_percent', 'Status'});
end
