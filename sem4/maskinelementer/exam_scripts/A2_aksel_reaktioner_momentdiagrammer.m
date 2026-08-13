%% TITLE AND PURPOSE
% A2 - Aksel med punktkraefter, lejereaktioner og momentdiagrammer
%
% Brug dette script naar:
% - akslen kan modelleres som en statisk bestemt bjaelke med to lejer;
% - punktkraefter og deres x-positioner er kendte i y- og z-plan;
% - eventuelle punktvise torsionsmomenter er kendte;
% - der skal findes reaktioner, V-, M- og torsionsdiagrammer samt
%   en statisk von Mises-kontrol.
%
% Brug ikke dette script naar:
% - der er mere end to radialt baerende lejer uden kendt lastfordeling;
% - der indgaar fordelte laster eller paatrykte boejningsmomenter;
% - deformationer eller lejestivheder skal indgaa i lastfordelingen;
% - der skal udføres udmattelsesberegning (brug A3);
% - snitkraefterne allerede er kendte i ét snit (brug A1).
%
% Bestem manuelt foer brug:
% - fritlegemediagram og kraftkomposanter Fy og Fz;
% - leje-, last- og momentpositioner;
% - stykvis akselgeometri;
% - lokale Kt-faktorer fra kursusfigurer eller tabeller.
%
% Standardinput og regressionstest er baseret paa:
% OVELSE_AKSLAR_v8 - Copy.pdf, bagaksel til kaededrevet koeretoej.

clear; clc; close all;

%% ASSUMPTIONS AND MANUAL INPUT
% Enheder: N, mm og MPa. Momenter indtastes i N*m og konverteres
% eksplicit til N*mm.
%
% Fortegn:
% - +x gaar fra venstre mod hoejre langs akslen.
% - positiv Fy virker i +y-retningen.
% - positiv Fz virker i +z-retningen.
% - positivt torsionsmoment virker om +x efter hoejrehaandsreglen.
%
% Reaktionerne maa ikke indgaa i lastvektorerne; de beregnes automatisk.
% Begge lejer optager radiallast, men ingen af dem overfoerer et
% boejningsmoment.
%
% Sammenhaeng mellem kraefter og boejningsmomenter:
% - Fy giver Mz.
% - Fz giver My.
%
% Tvaersnittet antages cirkulaert, massivt eller hult, og linearelastisk.
% Kt-faktorer antages ikke allerede at vaere inkluderet i lasterne.

%% INPUT
% ----- Aksel og lejer -----
shaftStart_mm = 0;                   % [mm] Venstre modelende
shaftEnd_mm = 1000;                  % [mm] Hoejre modelende
bearingPositions_mm = [100, 900];    % [mm] [leje 1, leje 2]

% ----- Ydre punktkraefter i y-retningen -----
loadPositionsY_mm = [0, 600, 1000]; % [mm] Positioner for Fy
pointLoadsY_N = [392, 588, 392];     % [N] Positiv i +y

% ----- Ydre punktkraefter i z-retningen -----
loadPositionsZ_mm = [0, 1000];       % [mm] Positioner for Fz
pointLoadsZ_N = [672.5, 672.5];      % [N] Positiv i +z

% ----- Paatrykte torsionsmomenter -----
torquePositions_mm = [0, 600, 1000];        % [mm] Momentpositioner
appliedTorques_Nm = [23.52, -47.04, 23.52]; % [N*m] Om +x

% ----- Stykvis cirkulaer akselgeometri -----
% Hvert afsnit starter ved den tilhoerende x-position og fortsaetter
% frem til naeste afsnit.
referenceDiameter_mm = 26.6;              % [mm] Kursusopgavens D
sectionStartPositions_mm = [0, 100, 900]; % [mm] Afsnitsstarter
outerDiameters_mm = [0.6, 1.0, 0.6] * ...
    referenceDiameter_mm;                 % [mm] Ydre diametre
innerDiameters_mm = [0, 0, 0];            % [mm] Indre diametre

% ----- Materiale og statisk krav -----
yieldStrength_MPa = 400;          % [MPa] Flydespaending
requiredSafetyFactor = 2.0;       % [-] Kraevet sikkerhed

% ----- Valgfrie lokale kritiske snit -----
% evaluationSide: -1 = venstre side, 0 = ved punktet, +1 = hoejre side.
% Den lokale diameter indtastes eksplicit, saa en skulders lille diameter
% ikke afhaenger af, hvilken side af springet der evalueres.
useCriticalSectionChecks = true;  % [logisk] Anvend Kt-kontrol

criticalSectionNames = [ ...
    "Venstre lejeskulder"; ...
    "Tandhjulssaede"; ...
    "Hoejre lejeskulder"];

criticalPositions_mm = [100; 600; 900];     % [mm] Snitposition
criticalEvaluationSide = [-1; 1; 1];        % [-] -1, 0 eller +1
criticalOuterDiameters_mm = [ ...
    0.6*referenceDiameter_mm; ...
    referenceDiameter_mm; ...
    0.6*referenceDiameter_mm];              % [mm] Lokal ydre diameter
criticalInnerDiameters_mm = [0; 0; 0];      % [mm] Lokal indre diameter
criticalKtBending = [1.35; 1.55; 1.35];     % [-] Kt for boejning
criticalKtTorsion = [1.20; 1.35; 1.20];     % [-] Kt for torsion

% ----- Numeriske indstillinger -----
plotStationCount = 2001;           % [-] Antal grundpunkter
eventOffsetFraction = 1e-9;        % [-] Offset omkring spring
relativeEquilibriumTolerance = 1e-10; % [-] Numerisk tolerance
runCourseTests = true;             % [logisk] Koer regressionstests

%% UNIT CHECK AND VALIDATION
bearingPositions_mm = bearingPositions_mm(:).';
loadPositionsY_mm = loadPositionsY_mm(:).';
pointLoadsY_N = pointLoadsY_N(:).';
loadPositionsZ_mm = loadPositionsZ_mm(:).';
pointLoadsZ_N = pointLoadsZ_N(:).';
torquePositions_mm = torquePositions_mm(:).';
appliedTorques_Nm = appliedTorques_Nm(:).';
sectionStartPositions_mm = sectionStartPositions_mm(:).';
outerDiameters_mm = outerDiameters_mm(:).';
innerDiameters_mm = innerDiameters_mm(:).';

assert(isfinite(shaftStart_mm) && isfinite(shaftEnd_mm) && ...
    shaftEnd_mm > shaftStart_mm, ...
    'Akslens start og slut skal vaere endelige og stigende.');

assert(numel(bearingPositions_mm) == 2 && ...
    all(isfinite(bearingPositions_mm)) && ...
    bearingPositions_mm(2) > bearingPositions_mm(1), ...
    'Angiv to endelige lejer i stigende x-raekkefoelge.');

assert(all(bearingPositions_mm >= shaftStart_mm & ...
           bearingPositions_mm <= shaftEnd_mm), ...
    'Lejerne skal ligge inden for akselmodellen.');

assert(numel(loadPositionsY_mm) == numel(pointLoadsY_N), ...
    'Fy-positioner og Fy-kraefter skal have samme laengde.');
assert(numel(loadPositionsZ_mm) == numel(pointLoadsZ_N), ...
    'Fz-positioner og Fz-kraefter skal have samme laengde.');
assert(numel(torquePositions_mm) == numel(appliedTorques_Nm), ...
    'Momentpositioner og torsionsmomenter skal have samme laengde.');

allLoadData = [loadPositionsY_mm, pointLoadsY_N, ...
    loadPositionsZ_mm, pointLoadsZ_N, ...
    torquePositions_mm, appliedTorques_Nm];

assert(all(isfinite(allLoadData)), ...
    'Alle laster, momenter og positioner skal vaere endelige.');

allExternalPositions_mm = [loadPositionsY_mm, ...
    loadPositionsZ_mm, torquePositions_mm];

assert(all(allExternalPositions_mm >= shaftStart_mm & ...
           allExternalPositions_mm <= shaftEnd_mm), ...
    'Alle laster og momenter skal ligge paa akslen.');

assert(~isempty(sectionStartPositions_mm) && ...
    numel(sectionStartPositions_mm) == numel(outerDiameters_mm) && ...
    numel(sectionStartPositions_mm) == numel(innerDiameters_mm), ...
    'Afsnitsstarter og diametervektorer skal have samme laengde.');

assert(abs(sectionStartPositions_mm(1) - shaftStart_mm) <= ...
    eps(max(1, abs(shaftStart_mm))) && ...
    all(diff(sectionStartPositions_mm) > 0) && ...
    sectionStartPositions_mm(end) < shaftEnd_mm, ...
    ['Foerste afsnit skal starte ved shaftStart_mm, og alle ', ...
     'afsnitsstarter skal vaere stigende.']);

assert(all(outerDiameters_mm > 0) && ...
    all(innerDiameters_mm >= 0) && ...
    all(innerDiameters_mm < outerDiameters_mm), ...
    'Hvert afsnit skal opfylde 0 <= d < D.');

assert(isfinite(yieldStrength_MPa) && yieldStrength_MPa > 0 && ...
    isfinite(requiredSafetyFactor) && requiredSafetyFactor > 0, ...
    'Materialedata og sikkerhedskrav skal vaere positive.');

assert(plotStationCount >= 101 && ...
    plotStationCount == round(plotStationCount), ...
    'plotStationCount skal vaere et heltal paa mindst 101.');

assert(eventOffsetFraction > 0 && eventOffsetFraction < 1e-3 && ...
    relativeEquilibriumTolerance > 0, ...
    'Numeriske tolerancer skal vaere positive og rimeligt smaa.');

assert(islogical(useCriticalSectionChecks) && ...
    isscalar(useCriticalSectionChecks) && ...
    islogical(runCourseTests) && isscalar(runCourseTests), ...
    'Logiske valg skal vaere true eller false.');

if useCriticalSectionChecks
    criticalSectionNames = criticalSectionNames(:);
    criticalPositions_mm = criticalPositions_mm(:);
    criticalEvaluationSide = criticalEvaluationSide(:);
    criticalOuterDiameters_mm = criticalOuterDiameters_mm(:);
    criticalInnerDiameters_mm = criticalInnerDiameters_mm(:);
    criticalKtBending = criticalKtBending(:);
    criticalKtTorsion = criticalKtTorsion(:);

    criticalLengths = [numel(criticalSectionNames), ...
        numel(criticalPositions_mm), ...
        numel(criticalEvaluationSide), ...
        numel(criticalOuterDiameters_mm), ...
        numel(criticalInnerDiameters_mm), ...
        numel(criticalKtBending), ...
        numel(criticalKtTorsion)];

    assert(all(criticalLengths == criticalLengths(1)), ...
        'Alle vektorer for kritiske snit skal have samme laengde.');

    assert(all(criticalPositions_mm >= shaftStart_mm & ...
               criticalPositions_mm <= shaftEnd_mm) && ...
        all(ismember(criticalEvaluationSide, [-1, 0, 1])), ...
        'Kontroller position og evaluationSide for kritiske snit.');

    assert(all(criticalOuterDiameters_mm > 0) && ...
        all(criticalInnerDiameters_mm >= 0) && ...
        all(criticalInnerDiameters_mm < criticalOuterDiameters_mm), ...
        'Kritiske snit skal opfylde 0 <= d < D.');

    assert(all(criticalKtBending >= 1) && ...
        all(criticalKtTorsion >= 1), ...
        'Kt-faktorer til denne statiske kontrol skal vaere >= 1.');
end

%% CALCULATION
% ----- Lejereaktioner beregnes separat i y- og z-plan -----
[reactionBearing1Y_N, reactionBearing2Y_N] = ...
    solveTwoSupportReactions( ...
    loadPositionsY_mm, pointLoadsY_N, bearingPositions_mm);

[reactionBearing1Z_N, reactionBearing2Z_N] = ...
    solveTwoSupportReactions( ...
    loadPositionsZ_mm, pointLoadsZ_N, bearingPositions_mm);

reactionForcesY_N = [reactionBearing1Y_N, reactionBearing2Y_N];
reactionForcesZ_N = [reactionBearing1Z_N, reactionBearing2Z_N];

allLoadPositionsY_mm = [loadPositionsY_mm, bearingPositions_mm];
allPointLoadsY_N = [pointLoadsY_N, reactionForcesY_N];

allLoadPositionsZ_mm = [loadPositionsZ_mm, bearingPositions_mm];
allPointLoadsZ_N = [pointLoadsZ_N, reactionForcesZ_N];

% Eksplicit konvertering fra N*m til N*mm
appliedTorques_Nmm = appliedTorques_Nm * 1e3;

% ----- Analysepunkter, inkl. begge sider af spring -----
shaftLength_mm = shaftEnd_mm - shaftStart_mm;
eventOffset_mm = max(eventOffsetFraction * shaftLength_mm, ...
    100*eps(max(abs([shaftStart_mm, shaftEnd_mm]))));

eventPositions_mm = unique([shaftStart_mm, shaftEnd_mm, ...
    allLoadPositionsY_mm, allLoadPositionsZ_mm, ...
    torquePositions_mm, sectionStartPositions_mm]);

if useCriticalSectionChecks
    eventPositions_mm = unique( ...
        [eventPositions_mm, criticalPositions_mm(:).']);
end

xStations_mm = unique([ ...
    linspace(shaftStart_mm, shaftEnd_mm, plotStationCount), ...
    eventPositions_mm, ...
    eventPositions_mm-eventOffset_mm, ...
    eventPositions_mm+eventOffset_mm]);

xStations_mm = xStations_mm( ...
    xStations_mm >= shaftStart_mm & ...
    xStations_mm <= shaftEnd_mm);

% ----- Forskydningskraefter, boejningsmomenter og torsion -----
[shearForceY_N, shearForceZ_N, ...
    bendingMomentY_Nmm, bendingMomentZ_Nmm, ...
    torsionalMoment_Nmm] = evaluateResultants( ...
    xStations_mm, ...
    allLoadPositionsY_mm, allPointLoadsY_N, ...
    allLoadPositionsZ_mm, allPointLoadsZ_N, ...
    torquePositions_mm, appliedTorques_Nmm);

bendingMomentResultant_Nmm = hypot( ...
    bendingMomentY_Nmm, bendingMomentZ_Nmm);

% ----- Stykvise tvaersnitsegenskaber -----
[localOuterDiameter_mm, localInnerDiameter_mm, ...
    sectionModulusBending_mm3, sectionModulusTorsion_mm3] = ...
    sectionPropertiesAtPositions( ...
    xStations_mm, sectionStartPositions_mm, ...
    outerDiameters_mm, innerDiameters_mm);

% ----- Nominelle spaendinger langs akslen -----
sigmaBendingNominal_MPa = ...
    bendingMomentResultant_Nmm ./ sectionModulusBending_mm3;

tauTorsionNominal_MPa = ...
    abs(torsionalMoment_Nmm) ./ sectionModulusTorsion_mm3;

sigmaVonMisesNominal_MPa = sqrt( ...
    sigmaBendingNominal_MPa.^2 + ...
    3*tauTorsionNominal_MPa.^2);

[maxBendingMoment_Nmm, maxBendingIndex] = ...
    max(bendingMomentResultant_Nmm);

maxBendingMoment_Nm = maxBendingMoment_Nmm/1e3;
maxBendingPosition_mm = xStations_mm(maxBendingIndex);

[maxNominalVonMises_MPa, nominalCriticalIndex] = ...
    max(sigmaVonMisesNominal_MPa);

nominalCriticalPosition_mm = xStations_mm(nominalCriticalIndex);
nominalCriticalDiameter_mm = ...
    localOuterDiameter_mm(nominalCriticalIndex);
nominalCriticalBendingMoment_Nm = ...
    bendingMomentResultant_Nmm(nominalCriticalIndex)/1e3;
nominalCriticalTorque_Nm = ...
    torsionalMoment_Nmm(nominalCriticalIndex)/1e3;

if maxNominalVonMises_MPa > 0
    nominalSafetyFactor = ...
        yieldStrength_MPa/maxNominalVonMises_MPa;
else
    nominalSafetyFactor = Inf;
end

% ----- Lokale Kt-kontroller -----
criticalSectionTable = table();
maxLocalVonMises_MPa = NaN;
minimumLocalSafetyFactor = NaN;
localCriticalSectionName = "Ikke beregnet";

if useCriticalSectionChecks
    criticalEvaluationPositions_mm = criticalPositions_mm + ...
        criticalEvaluationSide*eventOffset_mm;

    assert(all(criticalEvaluationPositions_mm >= shaftStart_mm & ...
               criticalEvaluationPositions_mm <= shaftEnd_mm), ...
        'Et kritisk snit evalueres uden for akslen.');

    [~, ~, criticalMy_Nmm, criticalMz_Nmm, criticalT_Nmm] = ...
        evaluateResultants( ...
        criticalEvaluationPositions_mm.', ...
        allLoadPositionsY_mm, allPointLoadsY_N, ...
        allLoadPositionsZ_mm, allPointLoadsZ_N, ...
        torquePositions_mm, appliedTorques_Nmm);

    criticalMy_Nmm = criticalMy_Nmm(:);
    criticalMz_Nmm = criticalMz_Nmm(:);
    criticalT_Nmm = criticalT_Nmm(:);
    criticalMres_Nmm = hypot(criticalMy_Nmm, criticalMz_Nmm);

    criticalSecondMomentArea_mm4 = pi/64 .* ...
        (criticalOuterDiameters_mm.^4 - ...
         criticalInnerDiameters_mm.^4);

    criticalPolarMomentArea_mm4 = pi/32 .* ...
        (criticalOuterDiameters_mm.^4 - ...
         criticalInnerDiameters_mm.^4);

    criticalWb_mm3 = criticalSecondMomentArea_mm4 ./ ...
        (criticalOuterDiameters_mm/2);

    criticalWt_mm3 = criticalPolarMomentArea_mm4 ./ ...
        (criticalOuterDiameters_mm/2);

    criticalSigmaBNominal_MPa = ...
        criticalMres_Nmm ./ criticalWb_mm3;

    criticalTauNominal_MPa = ...
        abs(criticalT_Nmm) ./ criticalWt_mm3;

    criticalSigmaVonMisesLocal_MPa = sqrt( ...
        (criticalKtBending .* criticalSigmaBNominal_MPa).^2 + ...
        3*(criticalKtTorsion .* criticalTauNominal_MPa).^2);

    criticalSafetyFactor = ...
        yieldStrength_MPa ./ criticalSigmaVonMisesLocal_MPa;
    criticalSafetyFactor(criticalSigmaVonMisesLocal_MPa == 0) = Inf;

    criticalSectionTable = table( ...
        criticalSectionNames, criticalPositions_mm, ...
        criticalEvaluationSide, criticalOuterDiameters_mm, ...
        criticalMres_Nmm/1e3, criticalT_Nmm/1e3, ...
        criticalSigmaBNominal_MPa, criticalTauNominal_MPa, ...
        criticalSigmaVonMisesLocal_MPa, criticalSafetyFactor, ...
        'VariableNames', {'Snit', 'x_mm', 'Side', 'D_mm', ...
        'Mres_Nm', 'T_Nm', 'sigmaB_nom_MPa', 'tauT_nom_MPa', ...
        'sigmaVM_lokal_MPa', 'Sikkerhed'});

    [maxLocalVonMises_MPa, localCriticalIndex] = ...
        max(criticalSigmaVonMisesLocal_MPa);

    minimumLocalSafetyFactor = ...
        min(criticalSafetyFactor);

    localCriticalSectionName = ...
        criticalSectionNames(localCriticalIndex);
end

%% RESULTS
fprintf('\n===== A2: LEJEREAKTIONER OG MOMENTDIAGRAMMER =====\n');

reactionTable = table( ...
    ["Leje 1"; "Leje 2"], bearingPositions_mm(:), ...
    reactionForcesY_N(:), reactionForcesZ_N(:), ...
    'VariableNames', {'Leje', 'x_mm', 'Ry_N', 'Rz_N'});

disp(reactionTable);

fprintf('M_res,max:                         %.3f N*m\n', ...
    maxBendingMoment_Nm);
fprintf('Position for M_res,max:            %.3f mm\n', ...
    maxBendingPosition_mm);
fprintf('Kritisk nominel position:          %.3f mm\n', ...
    nominalCriticalPosition_mm);
fprintf('Diameter ved nominelt kritisk snit: %.3f mm\n', ...
    nominalCriticalDiameter_mm);
fprintf('M_res ved nominelt kritisk snit:   %.3f N*m\n', ...
    nominalCriticalBendingMoment_Nm);
fprintf('T ved nominelt kritisk snit:       %+.3f N*m\n', ...
    nominalCriticalTorque_Nm);
fprintf('Maks. nominel von Mises:           %.3f MPa\n', ...
    maxNominalVonMises_MPa);
fprintf('Nominel sikkerhed mod flydning:    %.3f\n', ...
    nominalSafetyFactor);

if useCriticalSectionChecks
    fprintf('\nLokale kritiske snit:\n');
    disp(criticalSectionTable);
    fprintf('Maks. lokal von Mises:             %.3f MPa\n', ...
        maxLocalVonMises_MPa);
    fprintf('Kritisk lokalt snit:               %s\n', ...
        char(localCriticalSectionName));
    fprintf('Mindste lokal sikkerhed:           %.3f\n', ...
        minimumLocalSafetyFactor);
end

results = struct;
results.reactionTable = reactionTable;
results.xStations_mm = xStations_mm;
results.shearForceY_N = shearForceY_N;
results.shearForceZ_N = shearForceZ_N;
results.bendingMomentY_Nm = bendingMomentY_Nmm/1e3;
results.bendingMomentZ_Nm = bendingMomentZ_Nmm/1e3;
results.bendingMomentResultant_Nm = ...
    bendingMomentResultant_Nmm/1e3;
results.torsionalMoment_Nm = torsionalMoment_Nmm/1e3;
results.localOuterDiameter_mm = localOuterDiameter_mm;
results.localInnerDiameter_mm = localInnerDiameter_mm;
results.sigmaVonMisesNominal_MPa = sigmaVonMisesNominal_MPa;
results.maxBendingMoment_Nm = maxBendingMoment_Nm;
results.maxBendingPosition_mm = maxBendingPosition_mm;
results.maxNominalVonMises_MPa = maxNominalVonMises_MPa;
results.nominalSafetyFactor = nominalSafetyFactor;
results.criticalSectionTable = criticalSectionTable;
results.maxLocalVonMises_MPa = maxLocalVonMises_MPa;
results.minimumLocalSafetyFactor = minimumLocalSafetyFactor;

%% AUTOMATIC CHECKS
forceResidualY_N = sum(allPointLoadsY_N);
forceResidualZ_N = sum(allPointLoadsZ_N);

momentResidualY_Nmm = sum( ...
    allPointLoadsY_N .* ...
    (allLoadPositionsY_mm-bearingPositions_mm(1)));

momentResidualZ_Nmm = sum( ...
    allPointLoadsZ_N .* ...
    (allLoadPositionsZ_mm-bearingPositions_mm(1)));

torqueResidual_Nmm = sum(appliedTorques_Nmm);

forceToleranceY_N = relativeEquilibriumTolerance * ...
    max(1, sum(abs(allPointLoadsY_N)));
forceToleranceZ_N = relativeEquilibriumTolerance * ...
    max(1, sum(abs(allPointLoadsZ_N)));

momentToleranceY_Nmm = relativeEquilibriumTolerance * ...
    max(1, sum(abs(allPointLoadsY_N))*shaftLength_mm);
momentToleranceZ_Nmm = relativeEquilibriumTolerance * ...
    max(1, sum(abs(allPointLoadsZ_N))*shaftLength_mm);

torqueTolerance_Nmm = relativeEquilibriumTolerance * ...
    max(1, sum(abs(appliedTorques_Nmm)));

assert(abs(forceResidualY_N) <= forceToleranceY_N, ...
    'Fy-ligevaegten er ikke opfyldt.');
assert(abs(forceResidualZ_N) <= forceToleranceZ_N, ...
    'Fz-ligevaegten er ikke opfyldt.');
assert(abs(momentResidualY_Nmm) <= momentToleranceY_Nmm, ...
    'Momentligevaegten for Fy-laster er ikke opfyldt.');
assert(abs(momentResidualZ_Nmm) <= momentToleranceZ_Nmm, ...
    'Momentligevaegten for Fz-laster er ikke opfyldt.');

fprintf('\nOK: Kraft- og boejningsmomentligevaegt er opfyldt.\n');

if abs(torqueResidual_Nmm) <= torqueTolerance_Nmm
    fprintf('OK: De paatrykte torsionsmomenter er i ligevaegt.\n');
else
    fprintf(['ADVARSEL: Sum af paatrykte torsionsmomenter er ', ...
        '%+.3f N*m. Tilfoej den manglende torsionsreaktion.\n'], ...
        torqueResidual_Nmm/1e3);
end

if nominalSafetyFactor >= requiredSafetyFactor
    nominalStatus = "OK";
    fprintf(['OK: Nominel sikkerhed %.3f opfylder kravet %.3f ', ...
        'foer lokale Kt-faktorer.\n'], ...
        nominalSafetyFactor, requiredSafetyFactor);
else
    nominalStatus = "IKKE OK";
    fprintf(['IKKE OK: Nominel sikkerhed %.3f er mindre end ', ...
        'kravet %.3f.\n'], ...
        nominalSafetyFactor, requiredSafetyFactor);
end

if useCriticalSectionChecks
    if minimumLocalSafetyFactor >= requiredSafetyFactor
        localStatus = "OK";
        fprintf(['OK: Lokal sikkerhed %.3f opfylder kravet %.3f.\n'], ...
            minimumLocalSafetyFactor, requiredSafetyFactor);
    else
        localStatus = "IKKE OK";
        fprintf(['IKKE OK: Mindste lokale sikkerhed er %.3f i ', ...
            'snittet "%s"; kravet er %.3f.\n'], ...
            minimumLocalSafetyFactor, ...
            char(localCriticalSectionName), requiredSafetyFactor);
    end
else
    localStatus = "IKKE BEREGNET";
    fprintf('ADVARSEL: Lokale Kt-faktorer er ikke kontrolleret.\n');
end

results.nominalStatus = nominalStatus;
results.localStatus = localStatus;
results.forceResidualY_N = forceResidualY_N;
results.forceResidualZ_N = forceResidualZ_N;
results.torqueResidual_Nm = torqueResidual_Nmm/1e3;

%% PLOTS
xStations_m = xStations_mm/1e3;
bearingPositions_m = bearingPositions_mm/1e3;

figure('Name', 'A2 - Forskydningskraftdiagrammer');
tiledlayout(2, 1);

nexttile;
stairs(xStations_m, shearForceY_N, 'LineWidth', 1.4);
grid on;
xlabel('Position x [m]');
ylabel('V_y [N]');
title('Forskydningskraft fra Fy');
addBearingLines(bearingPositions_m);

nexttile;
stairs(xStations_m, shearForceZ_N, 'LineWidth', 1.4);
grid on;
xlabel('Position x [m]');
ylabel('V_z [N]');
title('Forskydningskraft fra Fz');
addBearingLines(bearingPositions_m);

figure('Name', 'A2 - Boejningsmomentdiagrammer');
tiledlayout(3, 1);

nexttile;
plot(xStations_m, bendingMomentY_Nmm/1e3, 'LineWidth', 1.4);
grid on;
xlabel('Position x [m]');
ylabel('M_y [N m]');
title('Boejningsmoment om y');
addBearingLines(bearingPositions_m);

nexttile;
plot(xStations_m, bendingMomentZ_Nmm/1e3, 'LineWidth', 1.4);
grid on;
xlabel('Position x [m]');
ylabel('M_z [N m]');
title('Boejningsmoment om z');
addBearingLines(bearingPositions_m);

nexttile;
plot(xStations_m, bendingMomentResultant_Nmm/1e3, ...
    'LineWidth', 1.4);
hold on;
plot(maxBendingPosition_mm/1e3, maxBendingMoment_Nm, ...
    'o', 'MarkerSize', 7, 'LineWidth', 1.4);
grid on;
xlabel('Position x [m]');
ylabel('M_{res} [N m]');
title('Resulterende boejningsmoment');
legend('M_{res}', 'Maksimum', 'Location', 'best');
addBearingLines(bearingPositions_m);

figure('Name', 'A2 - Torsion og statisk spaending');
tiledlayout(2, 1);

nexttile;
stairs(xStations_m, torsionalMoment_Nmm/1e3, ...
    'LineWidth', 1.4);
grid on;
xlabel('Position x [m]');
ylabel('T [N m]');
title('Internt torsionsmoment');
addBearingLines(bearingPositions_m);

nexttile;
plot(xStations_m, sigmaVonMisesNominal_MPa, ...
    'LineWidth', 1.4);
hold on;

if useCriticalSectionChecks
    scatter(criticalPositions_mm/1e3, ...
        criticalSigmaVonMisesLocal_MPa, 45, 'filled');
    legend('Nominel von Mises', 'Lokale K_t-kontroller', ...
        'Location', 'best');
else
    legend('Nominel von Mises', 'Location', 'best');
end

yline(yieldStrength_MPa/requiredSafetyFactor, '--', ...
    'Tilladt \sigma_{VM}');
grid on;
xlabel('Position x [m]');
ylabel('\sigma_{VM} [MPa]');
title('Statisk von Mises-spaending');
addBearingLines(bearingPositions_m);

%% PHYSICAL CONCLUSION
fprintf('\n===== FYSISK KONKLUSION =====\n');
fprintf(['Det stoerste resulterende boejningsmoment er %.3f N*m ', ...
    'ved x = %.3f mm.\n'], ...
    maxBendingMoment_Nm, maxBendingPosition_mm);

if nominalSafetyFactor >= requiredSafetyFactor
    fprintf(['Akslen opfylder den nominelle statiske kontrol med ', ...
        'sikkerhed %.3f.\n'], nominalSafetyFactor);
else
    fprintf(['Akslen opfylder ikke den nominelle statiske kontrol; ', ...
        'sikkerheden er %.3f.\n'], nominalSafetyFactor);
end

if useCriticalSectionChecks
    fprintf(['Med de indtastede Kt-faktorer er mindste lokale ', ...
        'sikkerhed %.3f i "%s".\n'], ...
        minimumLocalSafetyFactor, char(localCriticalSectionName));
end

fprintf(['Konklusionen afhaenger af fritlegemediagram, fortegn, ', ...
    'lejemodel, diameterinddeling og manuelt aflæste Kt-faktorer. ', ...
    'Udmattelse er ikke kontrolleret.\n']);

%% OPTIONAL TEST CASES
if runCourseTests
    fprintf('\n===== INDBYGGEDE TESTS =====\n');

    % Test 1: Kursusoevelse, bagaksel til kaededrevet koeretoej.
    testBearing_mm = [100, 900];
    testPosY_mm = [0, 600, 1000];
    testFy_N = [392, 588, 392];
    testPosZ_mm = [0, 1000];
    testFz_N = [672.5, 672.5];

    [testR1Y_N, testR2Y_N] = solveTwoSupportReactions( ...
        testPosY_mm, testFy_N, testBearing_mm);
    [testR1Z_N, testR2Z_N] = solveTwoSupportReactions( ...
        testPosZ_mm, testFz_N, testBearing_mm);

    testAllPosY_mm = [testPosY_mm, testBearing_mm];
    testAllFy_N = [testFy_N, testR1Y_N, testR2Y_N];
    testAllPosZ_mm = [testPosZ_mm, testBearing_mm];
    testAllFz_N = [testFz_N, testR1Z_N, testR2Z_N];

    testX_mm = [100, 600, 900];

    [~, ~, testMy_Nmm, testMz_Nmm, testT_Nmm] = ...
        evaluateResultants( ...
        testX_mm, ...
        testAllPosY_mm, testAllFy_N, ...
        testAllPosZ_mm, testAllFz_N, ...
        [0, 600, 1000], [23.52, -47.04, 23.52]*1e3);

    testMres_Nm = hypot(testMy_Nmm, testMz_Nmm)/1e3;

    testD_mm = 26.6;
    testd_mm = 0.6*testD_mm;
    testWbSmall_mm3 = pi*testd_mm^3/32;
    testWtSmall_mm3 = pi*testd_mm^3/16;

    testSigmaBShoulder_MPa = ...
        testMres_Nm(1)*1e3/testWbSmall_mm3;
    testTauShoulder_MPa = ...
        abs(testT_Nmm(1))/testWtSmall_mm3;

    % Slides anvender de afrundede nominelle vaerdier 200 og 29.5 MPa.
    testLocalShoulder_MPa = sqrt( ...
        (1.35*200)^2 + 3*(1.20*29.5)^2);

    % Slides anvender 53 og 6.4 MPa ved tandhjulssaedet.
    testLocalGear_MPa = sqrt( ...
        (1.55*53)^2 + 3*(1.35*6.4)^2);

    testName = [ ...
        "R1y"; "R2y"; "R1z"; "R2z"; ...
        "Mres ved x=0.1 m"; "Mres ved x=0.6 m"; ...
        "sigma_b ved skulder"; "tau ved skulder"; ...
        "lokal VM ved skulder"; "lokal VM ved tandhjul"];

    calculatedValue = [ ...
        testR1Y_N; testR2Y_N; testR1Z_N; testR2Z_N; ...
        testMres_Nm(1); testMres_Nm(2); ...
        testSigmaBShoulder_MPa; testTauShoulder_MPa; ...
        testLocalShoulder_MPa; testLocalGear_MPa];

    courseValue = [ ...
        -613; -760; -672; -672; ...
        78; 98; 200; 29.5; 277; 83];

    tolerance = [1; 1; 1; 1; 1; 1; 6; 0.1; 1; 1];
    passed = abs(calculatedValue-courseValue) <= tolerance;

    courseTestResults = table( ...
        testName, calculatedValue, courseValue, tolerance, passed);
    disp(courseTestResults);

    assert(all(passed), ...
        'Mindst én kursustest ligger uden for tolerancen.');

    % Test 2: Haandkontrol.
    % Simpelt understøttet bjaelke, L=1000 mm, F=-1000 N i midten:
    % R1=R2=500 N og |Mmax|=250 N*m.
    [simpleR1_N, simpleR2_N] = solveTwoSupportReactions( ...
        500, -1000, [0, 1000]);

    [~, ~, ~, simpleMz_Nmm, ~] = evaluateResultants( ...
        500, [500, 0, 1000], ...
        [-1000, simpleR1_N, simpleR2_N], ...
        0, 0, 0, 0);

    assert(abs(simpleR1_N-500) < 1e-10 && ...
        abs(simpleR2_N-500) < 1e-10 && ...
        abs(abs(simpleMz_Nmm)/1e3-250) < 1e-10, ...
        'Den simple haandkontrol fejlede.');

    fprintf(['OK: Kursusoevelsen og den simple haandkontrol ', ...
        'ligger inden for tolerancerne.\n']);
end

%% LOCAL FUNCTIONS
function [reaction1_N, reaction2_N] = ...
    solveTwoSupportReactions( ...
    loadPositions_mm, pointLoads_N, bearingPositions_mm)
% Reaktioner for en statisk bestemt bjaelke med to simple lejer.

    loadPositions_mm = loadPositions_mm(:).';
    pointLoads_N = pointLoads_N(:).';
    bearingPositions_mm = bearingPositions_mm(:).';

    bearingSpan_mm = ...
        bearingPositions_mm(2)-bearingPositions_mm(1);

    reaction2_N = -sum(pointLoads_N .* ...
        (loadPositions_mm-bearingPositions_mm(1))) / ...
        bearingSpan_mm;

    reaction1_N = -sum(pointLoads_N)-reaction2_N;
end

function [shearForceY_N, shearForceZ_N, ...
    bendingMomentY_Nmm, bendingMomentZ_Nmm, ...
    torsionalMoment_Nmm] = evaluateResultants( ...
    xEvaluation_mm, ...
    loadPositionsY_mm, pointLoadsY_N, ...
    loadPositionsZ_mm, pointLoadsZ_N, ...
    torquePositions_mm, appliedTorques_Nmm)
% Snitkraefter beregnet ved ligevaegt af venstre akselstykke.

    xEvaluation_mm = xEvaluation_mm(:).';
    loadPositionsY_mm = loadPositionsY_mm(:).';
    pointLoadsY_N = pointLoadsY_N(:).';
    loadPositionsZ_mm = loadPositionsZ_mm(:).';
    pointLoadsZ_N = pointLoadsZ_N(:).';
    torquePositions_mm = torquePositions_mm(:).';
    appliedTorques_Nmm = appliedTorques_Nmm(:).';

    numberOfStations = numel(xEvaluation_mm);

    shearForceY_N = zeros(1, numberOfStations);
    shearForceZ_N = zeros(1, numberOfStations);
    bendingMomentY_Nmm = zeros(1, numberOfStations);
    bendingMomentZ_Nmm = zeros(1, numberOfStations);
    torsionalMoment_Nmm = zeros(1, numberOfStations);

    positionTolerance_mm = ...
        100*eps(max(1, max(abs(xEvaluation_mm))));

    for stationIndex = 1:numberOfStations
        x_mm = xEvaluation_mm(stationIndex);

        yOnLeft = loadPositionsY_mm <= ...
            x_mm+positionTolerance_mm;
        zOnLeft = loadPositionsZ_mm <= ...
            x_mm+positionTolerance_mm;
        torqueOnLeft = torquePositions_mm <= ...
            x_mm+positionTolerance_mm;

        shearForceY_N(stationIndex) = ...
            sum(pointLoadsY_N(yOnLeft));
        shearForceZ_N(stationIndex) = ...
            sum(pointLoadsZ_N(zOnLeft));

        % Fy giver Mz.
        bendingMomentZ_Nmm(stationIndex) = sum( ...
            pointLoadsY_N(yOnLeft) .* ...
            (x_mm-loadPositionsY_mm(yOnLeft)));

        % Fz giver My med modsat fortegn fra krydsproduktet.
        bendingMomentY_Nmm(stationIndex) = -sum( ...
            pointLoadsZ_N(zOnLeft) .* ...
            (x_mm-loadPositionsZ_mm(zOnLeft)));

        % Internt T balancerer ydre momenter til venstre.
        torsionalMoment_Nmm(stationIndex) = ...
            -sum(appliedTorques_Nmm(torqueOnLeft));
    end
end

function [outerDiameterAtX_mm, innerDiameterAtX_mm, ...
    sectionModulusBendingAtX_mm3, ...
    sectionModulusTorsionAtX_mm3] = ...
    sectionPropertiesAtPositions( ...
    xEvaluation_mm, sectionStartPositions_mm, ...
    outerDiameters_mm, innerDiameters_mm)
% Tvaersnitsegenskaber for en stykvis massiv eller hul cirkulaer aksel.

    xEvaluation_mm = xEvaluation_mm(:).';
    sectionStartPositions_mm = sectionStartPositions_mm(:).';
    outerDiameters_mm = outerDiameters_mm(:).';
    innerDiameters_mm = innerDiameters_mm(:).';

    numberOfStations = numel(xEvaluation_mm);
    outerDiameterAtX_mm = zeros(1, numberOfStations);
    innerDiameterAtX_mm = zeros(1, numberOfStations);
    sectionModulusBendingAtX_mm3 = zeros(1, numberOfStations);
    sectionModulusTorsionAtX_mm3 = zeros(1, numberOfStations);

    positionTolerance_mm = ...
        100*eps(max(1, max(abs(xEvaluation_mm))));

    for stationIndex = 1:numberOfStations
        x_mm = xEvaluation_mm(stationIndex);

        sectionIndex = find( ...
            sectionStartPositions_mm <= ...
            x_mm+positionTolerance_mm, 1, 'last');

        D_mm = outerDiameters_mm(sectionIndex);
        d_mm = innerDiameters_mm(sectionIndex);

        secondMomentArea_mm4 = ...
            pi/64*(D_mm^4-d_mm^4);
        polarMomentArea_mm4 = ...
            pi/32*(D_mm^4-d_mm^4);

        outerDiameterAtX_mm(stationIndex) = D_mm;
        innerDiameterAtX_mm(stationIndex) = d_mm;

        sectionModulusBendingAtX_mm3(stationIndex) = ...
            secondMomentArea_mm4/(D_mm/2);

        sectionModulusTorsionAtX_mm3(stationIndex) = ...
            polarMomentArea_mm4/(D_mm/2);
    end
end

function addBearingLines(bearingPositions_m)
% Markerer lejerne i det aktuelle diagram.

    xline(bearingPositions_m(1), ':', 'Leje 1', ...
        'LabelVerticalAlignment', 'bottom');
    xline(bearingPositions_m(2), ':', 'Leje 2', ...
        'LabelVerticalAlignment', 'bottom');
end
