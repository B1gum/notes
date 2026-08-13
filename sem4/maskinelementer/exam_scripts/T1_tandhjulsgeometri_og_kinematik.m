%% T1 - TANDHJULSGEOMETRI OG KINEMATIK
% Brug dette script naar en opgave omhandler standard, ligefortandede,
% udvendige evolventetandhjul i et eller flere sekventielle trin.
%
% Brug ikke dette script til skraafortanding, keglehjul, indvendige hjul,
% profilforskydning, ikke-standard centerafstande, kraefter (T2) eller
% tandfodsspaendinger (T3).
%
% Modeller/opslag manuelt foerst:
% 1) Fastlaeg kraftvejen og hvilket hjul der driver i hvert trin.
% 2) Fastlaeg hvilke hjul der sidder paa samme mellem-aksel.
% 3) Indtast tandtal, modul, indgrebsvinkel og indgangshastighed.
% Kursusgrundlag: TANDHJUL_FRL.pdf, især side 12-18, samt
% TANDHJUL_OPGAVE_LOSN.pdf, især side 7, 9 og 10.
% Scriptet antager, at det drevne hjul i trin k deler aksel med det
% drivende hjul i trin k+1.

%% ASSUMPTIONS AND MANUAL INPUT
% - Udvendige, ligefortandede standardhjul uden profilforskydning.
% - Samme modul og indgrebsvinkel for begge hjul i hvert indgreb.
% - Udveksling defineres som:
%       i = omega_drivende/omega_drevet = z_drevet/z_drivende
% - Positiv rotationsretning vaelges frit ved indgangen.
% - Hvert udvendigt indgreb vender rotationsretningen.
% - Enhedssystem: N, mm, s, rpm og rad/s.
% - Standard tandhoejder fra kursusmaterialet:
%       addendum = 1.00*m, dedendum = 1.25*m, frigang = 0.25*m.
% - Beregnet centerafstand er standardcenterafstanden C=(d1+d2)/2.
%   En eventuelt opgivet centerafstand bruges kun som kontrol.

%% INPUT
% Et element pr. tandhjulstrin. Eksemplet er kursusopgavens to-trins gear.
zDrive = [17, 18];              % [-] tandtal paa drivende hjul i hvert trin
zDriven = [100, 45];            % [-] tandtal paa drevet hjul i hvert trin
moduleStage = [2, 4];           % [mm] modul i hvert tandhjulsindgreb
pressureAngleDeg = [20, 20];    % [deg] indgrebsvinkel i hvert indgreb

inputSpeedRPM = 1800;           % [rpm] omdrejningstal paa indgangsakslen
inputDirection = +1;            % [-] +1 eller -1, valgfri positiv retning

% Kursusstandard og kontrolgraenser
toothStandard.addendumFactor = 1.00;  % [-] a/m
toothStandard.dedendumFactor = 1.25;  % [-] b/m
toothStandard.clearanceFactor = 0.25; % [-] c/m
minimumContactRatio = 1.20;            % [-] kursuskrav til indgrebsgrad

% Valgfrie krav/oplysninger. Brug NaN, naar de ikke er opgivet.
givenCenterDistanceMM = [NaN, NaN];    % [mm] opgivet centerafstand pr. trin
centerDistanceToleranceMM = 1e-6;      % [mm] tolerance ved centerafstandskontrol
targetOutputSpeedRPM = NaN;            % [rpm] valgfrit krav til udgangshastighed
targetOutputOmegaRadPerSec = 12;       % [rad/s] valgfrit krav; kun ét hastighedskrav
targetTolerancePercent = 1.0;          % [%] tilladt relativ afvigelse

% Visning og indbyggede regressionstests
makeSpeedPlot = true;                  % [-] true giver hastighedsplot
runCourseRegressionTests = true;       % [-] test mod kursusopgaver

%% UNIT CHECK AND VALIDATION
isFiniteNumeric = @(x) ~isnan(x) & ~isinf(x);

% Gør alle trinvise input til raekkevektorer.
zDrive = zDrive(:).';
zDriven = zDriven(:).';
moduleStage = moduleStage(:).';
pressureAngleDeg = pressureAngleDeg(:).';
givenCenterDistanceMM = givenCenterDistanceMM(:).';

numberOfStages = numel(zDrive);

assert(numberOfStages >= 1, ...
    'Der skal vaere mindst ét tandhjulstrin.');
assert(numel(zDriven) == numberOfStages && ...
       numel(moduleStage) == numberOfStages && ...
       numel(pressureAngleDeg) == numberOfStages, ...
    'zDrive, zDriven, moduleStage og pressureAngleDeg skal have samme laengde.');
assert(numel(givenCenterDistanceMM) == numberOfStages, ...
    'givenCenterDistanceMM skal have ét element pr. trin.');

assert(all(isFiniteNumeric(zDrive)) && all(isFiniteNumeric(zDriven)), ...
    'Tandtallene skal vaere endelige tal.');
assert(all(zDrive > 0) && all(zDriven > 0), ...
    'Tandtallene skal vaere positive.');
assert(all(mod(zDrive,1) == 0) && all(mod(zDriven,1) == 0), ...
    'Tandtallene skal vaere hele tal.');

assert(all(isFiniteNumeric(moduleStage)) && all(moduleStage > 0), ...
    'Alle moduler skal vaere positive og endelige [mm].');
assert(all(isFiniteNumeric(pressureAngleDeg)) && ...
       all(pressureAngleDeg > 0 & pressureAngleDeg < 90), ...
    'Indgrebsvinkler skal ligge mellem 0 og 90 grader.');
assert(isFiniteNumeric(inputSpeedRPM) && inputSpeedRPM > 0, ...
    'inputSpeedRPM skal vaere positiv [rpm].');
assert(isscalar(inputDirection) && any(inputDirection == [-1, +1]), ...
    'inputDirection skal vaere +1 eller -1.');

assert(toothStandard.addendumFactor > 0 && ...
       toothStandard.dedendumFactor > 0 && ...
       toothStandard.clearanceFactor >= 0, ...
    'Tandhoejdefaktorerne skal vaere fysisk mulige.');
assert(abs(toothStandard.dedendumFactor - ...
    (toothStandard.addendumFactor + toothStandard.clearanceFactor)) < 1e-12, ...
    'Kursusstandarden forventer dedendumFactor = addendumFactor + clearanceFactor.');

assert(isFiniteNumeric(minimumContactRatio) && minimumContactRatio > 0, ...
    'minimumContactRatio skal vaere positiv.');
assert(all(isnan(givenCenterDistanceMM) | ...
    (isFiniteNumeric(givenCenterDistanceMM) & givenCenterDistanceMM > 0)), ...
    'Opgivne centerafstande skal vaere positive [mm] eller NaN.');
assert(isFiniteNumeric(centerDistanceToleranceMM) && centerDistanceToleranceMM >= 0, ...
    'centerDistanceToleranceMM skal vaere ikke-negativ.');

hasTargetRPM = isFiniteNumeric(targetOutputSpeedRPM);
hasTargetOmega = isFiniteNumeric(targetOutputOmegaRadPerSec);
assert(~(hasTargetRPM && hasTargetOmega), ...
    'Angiv kun targetOutputSpeedRPM eller targetOutputOmegaRadPerSec, ikke begge.');
if hasTargetRPM
    assert(targetOutputSpeedRPM > 0, ...
        'targetOutputSpeedRPM skal vaere positiv.');
end
if hasTargetOmega
    assert(targetOutputOmegaRadPerSec > 0, ...
        'targetOutputOmegaRadPerSec skal vaere positiv.');
end
assert(isFiniteNumeric(targetTolerancePercent) && targetTolerancePercent >= 0, ...
    'targetTolerancePercent skal vaere ikke-negativ.');

if any(abs(pressureAngleDeg - 20) > 1e-12)
    warning('T1:NonStandardPressureAngle', ...
        ['Kursets standardvinkel er 20 deg. Kontrollér, at den valgte ', ...
         'indgrebsvinkel er opgivet i opgaven.']);
end

%% CALCULATION
calculation = calculateT1GearTrain( ...
    zDrive, zDriven, moduleStage, pressureAngleDeg, ...
    inputSpeedRPM, inputDirection, toothStandard, minimumContactRatio);

% Kontrol mod eventuelt opgivet centerafstand
centerDistanceDifferenceMM = givenCenterDistanceMM - calculation.centerDistanceMM;
centerDistanceSpecified = isFiniteNumeric(givenCenterDistanceMM);
centerDistanceOK = true(1, numberOfStages);
centerDistanceOK(centerDistanceSpecified) = ...
    abs(centerDistanceDifferenceMM(centerDistanceSpecified)) <= ...
    centerDistanceToleranceMM;

centerDistanceStatus = repmat("IKKE OPGIVET", numberOfStages, 1);
centerDistanceSpecifiedColumn = centerDistanceSpecified(:);
centerDistanceOKColumn = centerDistanceOK(:);
centerDistanceStatus(centerDistanceSpecifiedColumn & centerDistanceOKColumn) = "OK";
centerDistanceStatus(centerDistanceSpecifiedColumn & ~centerDistanceOKColumn) = "ADVARSEL";

% Kontaktgraden er kun direkte gyldig for standardcenterafstanden.
contactRatioValidForGivenCenter = ~centerDistanceSpecified | centerDistanceOK;
contactStatus = repmat("OK", numberOfStages, 1);
contactStatus(calculation.contactRatio(:) < minimumContactRatio) = "IKKE OK";
contactStatus(~contactRatioValidForGivenCenter(:)) = ...
    "ADVARSEL: C er ikke standard";

% Valgfri kontrol af udgangshastighed
outputSpeedMagnitudeRPM = abs(calculation.signedShaftSpeedRPM(end));
outputOmegaMagnitudeRadPerSec = ...
    abs(calculation.signedShaftOmegaRadPerSec(end));

targetCheckPerformed = false;
targetSpeedErrorPercent = NaN;
targetSpeedOK = true;

if hasTargetRPM
    targetCheckPerformed = true;
    targetSpeedErrorPercent = ...
        abs(outputSpeedMagnitudeRPM - targetOutputSpeedRPM) / ...
        targetOutputSpeedRPM * 100;
    targetSpeedOK = targetSpeedErrorPercent <= targetTolerancePercent;
elseif hasTargetOmega
    targetCheckPerformed = true;
    targetSpeedErrorPercent = ...
        abs(outputOmegaMagnitudeRadPerSec - targetOutputOmegaRadPerSec) / ...
        targetOutputOmegaRadPerSec * 100;
    targetSpeedOK = targetSpeedErrorPercent <= targetTolerancePercent;
end

%% RESULTS
% Gear-tabel: to hjul pr. trin.
gearID = strings(2*numberOfStages, 1);
gearRole = strings(2*numberOfStages, 1);
stageColumn = repelem((1:numberOfStages).', 2);

for k = 1:numberOfStages
    gearID(2*k-1) = "H" + string(2*k-1);
    gearID(2*k)   = "H" + string(2*k);
    gearRole(2*k-1) = "Drivende";
    gearRole(2*k)   = "Drevet";
end

teethColumn = reshape([zDrive; zDriven], [], 1);
moduleColumnMM = reshape([moduleStage; moduleStage], [], 1);
pressureAngleColumnDeg = ...
    reshape([pressureAngleDeg; pressureAngleDeg], [], 1);
pitchDiameterColumnMM = reshape([ ...
    calculation.driveGeometry.pitchDiameterMM; ...
    calculation.drivenGeometry.pitchDiameterMM], [], 1);
addendumDiameterColumnMM = reshape([ ...
    calculation.driveGeometry.addendumDiameterMM; ...
    calculation.drivenGeometry.addendumDiameterMM], [], 1);
rootDiameterColumnMM = reshape([ ...
    calculation.driveGeometry.rootDiameterMM; ...
    calculation.drivenGeometry.rootDiameterMM], [], 1);
baseDiameterColumnMM = reshape([ ...
    calculation.driveGeometry.baseDiameterMM; ...
    calculation.drivenGeometry.baseDiameterMM], [], 1);
circularPitchColumnMM = reshape([ ...
    calculation.driveGeometry.circularPitchMM; ...
    calculation.drivenGeometry.circularPitchMM], [], 1);
addendumColumnMM = reshape([ ...
    calculation.driveGeometry.addendumMM; ...
    calculation.drivenGeometry.addendumMM], [], 1);
dedendumColumnMM = reshape([ ...
    calculation.driveGeometry.dedendumMM; ...
    calculation.drivenGeometry.dedendumMM], [], 1);
clearanceColumnMM = reshape([ ...
    calculation.driveGeometry.clearanceMM; ...
    calculation.drivenGeometry.clearanceMM], [], 1);

gearTable = table( ...
    stageColumn, gearID, gearRole, teethColumn, moduleColumnMM, ...
    pressureAngleColumnDeg, pitchDiameterColumnMM, ...
    addendumDiameterColumnMM, rootDiameterColumnMM, ...
    baseDiameterColumnMM, circularPitchColumnMM, ...
    addendumColumnMM, dedendumColumnMM, clearanceColumnMM, ...
    'VariableNames', { ...
    'Stage','GearID','Role','Teeth','Module_mm','PressureAngle_deg', ...
    'PitchDiameter_mm','AddendumDiameter_mm','RootDiameter_mm', ...
    'BaseDiameter_mm','CircularPitch_mm','Addendum_mm', ...
    'Dedendum_mm','Clearance_mm'});

stageTable = table( ...
    (1:numberOfStages).', zDrive.', zDriven.', ...
    calculation.stageRatio.', calculation.shaftSpeedRPM(1:end-1).', ...
    calculation.shaftSpeedRPM(2:end).', ...
    calculation.centerDistanceMM.', calculation.pathOfContactMM.', ...
    calculation.basePitchMM.', calculation.contactRatio.', ...
    givenCenterDistanceMM.', centerDistanceDifferenceMM.', ...
    centerDistanceStatus, contactStatus, ...
    'VariableNames', { ...
    'Stage','DriveTeeth','DrivenTeeth','StageRatio', ...
    'InputSpeed_rpm','OutputSpeed_rpm','CenterDistance_mm', ...
    'PathOfContact_mm','BasePitch_mm','ContactRatio', ...
    'GivenCenterDistance_mm','CenterDifference_mm', ...
    'CenterStatus','ContactStatus'});

shaftTable = table( ...
    (1:numberOfStages+1).', calculation.shaftSpeedRPM.', ...
    calculation.shaftOmegaRadPerSec.', calculation.shaftDirection.', ...
    calculation.signedShaftSpeedRPM.', ...
    calculation.signedShaftOmegaRadPerSec.', ...
    'VariableNames', { ...
    'Shaft','SpeedMagnitude_rpm','OmegaMagnitude_rad_s','Direction', ...
    'SignedSpeed_rpm','SignedOmega_rad_s'});

fprintf('\nT1 - TANDHJULSGEOMETRI OG KINEMATIK\n');
fprintf('Definition: i = omega_drivende/omega_drevet = z_drevet/z_drivende\n');
fprintf('Antal trin: %d\n', numberOfStages);
fprintf('Samlet udveksling i_total: %.6f\n', calculation.totalRatio);
fprintf('Udgangshastighed: %.3f rpm = %.6f rad/s\n', ...
    outputSpeedMagnitudeRPM, outputOmegaMagnitudeRadPerSec);
fprintf('Udgangsretning relativt til indgang: %+d\n\n', ...
    calculation.shaftDirection(end));

disp('Tandhjulsgeometri:')
disp(gearTable)

disp('Indgreb og udveksling pr. trin:')
disp(stageTable)

disp('Akselhastigheder:')
disp(shaftTable)

results = struct;
results.input = struct( ...
    'zDrive', zDrive, ...
    'zDriven', zDriven, ...
    'moduleStageMM', moduleStage, ...
    'pressureAngleDeg', pressureAngleDeg, ...
    'inputSpeedRPM', inputSpeedRPM, ...
    'inputDirection', inputDirection);
results.gearTable = gearTable;
results.stageTable = stageTable;
results.shaftTable = shaftTable;
results.stageRatio = calculation.stageRatio;
results.totalRatio = calculation.totalRatio;
results.outputSpeedRPM = outputSpeedMagnitudeRPM;
results.outputOmegaRadPerSec = outputOmegaMagnitudeRadPerSec;
results.outputDirection = calculation.shaftDirection(end);
results.contactRatio = calculation.contactRatio;
results.minimumContactRatio = minimumContactRatio;
results.targetCheckPerformed = targetCheckPerformed;
results.targetSpeedErrorPercent = targetSpeedErrorPercent;
results.targetSpeedOK = targetSpeedOK;

%% AUTOMATIC CHECKS
for k = 1:numberOfStages
    if ~contactRatioValidForGivenCenter(k)
        fprintf(['ADVARSEL - trin %d: Opgivet centerafstand afviger %.6g mm ', ...
            'fra standardcenterafstanden. Den beregnede indgrebsgrad maa ', ...
            'ikke anvendes ukritisk.\n'], ...
            k, centerDistanceDifferenceMM(k));
    elseif calculation.contactRatio(k) >= minimumContactRatio
        fprintf('OK - trin %d: Indgrebsgrad %.3f >= %.2f.\n', ...
            k, calculation.contactRatio(k), minimumContactRatio);
    else
        fprintf('IKKE OK - trin %d: Indgrebsgrad %.3f < %.2f.\n', ...
            k, calculation.contactRatio(k), minimumContactRatio);
    end
end

if targetCheckPerformed
    if targetSpeedOK
        fprintf('OK - udgangshastighedens afvigelse er %.3f %% <= %.3f %%.\n', ...
            targetSpeedErrorPercent, targetTolerancePercent);
    else
        fprintf(['IKKE OK - udgangshastighedens afvigelse er %.3f %% ', ...
            '> %.3f %%.\n'], ...
            targetSpeedErrorPercent, targetTolerancePercent);
    end
else
    fprintf('ADVARSEL - intet krav til udgangshastighed er angivet.\n');
end

%% PLOTS
if makeSpeedPlot
    figure('Name','T1 - akselhastigheder');
    plot(1:numberOfStages+1, calculation.signedShaftSpeedRPM, ...
        'o-', 'LineWidth', 1.2, 'MarkerSize', 6);
    yline(0, '--');
    grid on
    xlabel('Akselnummer [-]');
    ylabel('Signeret omdrejningstal [rpm]');
    title('Akselhastighed og rotationsretning gennem geartrinnene');
    xticks(1:numberOfStages+1);
end

%% PHYSICAL CONCLUSION
if all(calculation.contactRatio >= minimumContactRatio) && ...
        all(contactRatioValidForGivenCenter)
    fprintf(['FYSISK KONKLUSION: Alle geartrin har tilstraekkelig ', ...
        'indgrebsgrad efter kursuskravet og standardgeometrien er ', ...
        'konsistent.\n']);
else
    fprintf(['FYSISK KONKLUSION: Mindst ét trin kraever ny vurdering af ', ...
        'tandtal, modul, indgrebsvinkel, centerafstand eller ', ...
        'profilforskydning.\n']);
end
fprintf(['Kraefter, effekt, virkningsgrad og tandspaendinger er ikke ', ...
    'beregnet i T1 og skal behandles i T2/T3.\n']);

%% OPTIONAL TEST CASES
if runCourseRegressionTests
    testName = strings(3,1);
    testPassed = false(3,1);
    testDetail = strings(3,1);

    % Test 1: Forelaesningsopgave, m=4 mm og z=30.
    testName(1) = "Forelaesning: m=4 mm, z=30";
    lectureGeometry = standardSpurGearGeometry( ...
        30, 4, 20, toothStandard);

    lectureActual = [ ...
        lectureGeometry.addendumMM, ...
        lectureGeometry.dedendumMM, ...
        lectureGeometry.clearanceMM, ...
        lectureGeometry.addendumDiameterMM, ...
        lectureGeometry.rootDiameterMM, ...
        lectureGeometry.baseDiameterMM, ...
        lectureGeometry.pitchDiameterMM, ...
        lectureGeometry.circularPitchMM];

    % Kursusresultater: 4; 5; 1; 128; 110; 112.8; 120; 12.6 mm.
    % De uafrundede referencevaerdier bruges i regressionstesten.
    lectureExpected = [ ...
        4, 5, 1, 128, 110, 112.763114494309, 120, 12.566370614359];
    testPassed(1) = max(abs(lectureActual - lectureExpected)) < 1e-9;
    testDetail(1) = sprintf( ...
        'Maks. absolut afvigelse = %.3g mm', ...
        max(abs(lectureActual - lectureExpected)));

    % Test 2: Kursusopgavens to-trins gear.
    testName(2) = "Kursusopgave: z=[17/100, 17/74]";
    courseCase = calculateT1GearTrain( ...
        [17,17], [100,74], [2,3], [20,20], ...
        2930, +1, toothStandard, 1.20);

    courseActual = [ ...
        courseCase.driveGeometry.pitchDiameterMM, ...
        courseCase.drivenGeometry.pitchDiameterMM, ...
        courseCase.contactRatio, ...
        abs(courseCase.signedShaftOmegaRadPerSec(end))];

    % Reference: d1=34, d3=51, d2=200, d4=222 mm,
    % mc12=1.683655..., mc34=1.665088..., omega_ud=11.982912 rad/s.
    courseExpected = [ ...
        34, 51, 200, 222, ...
        1.683655370525, 1.665088166921, 11.982911762524];

    courseDeviationPercent = ...
        abs(abs(courseCase.signedShaftOmegaRadPerSec(end)) - 12) / 12 * 100;

    testPassed(2) = ...
        max(abs(courseActual - courseExpected)) < 1e-9 && ...
        abs(courseDeviationPercent - 0.142401978970) < 1e-9;
    testDetail(2) = sprintf( ...
        'omega_ud = %.6f rad/s; afvigelse fra 12 rad/s = %.4f %%', ...
        abs(courseCase.signedShaftOmegaRadPerSec(end)), ...
        courseDeviationPercent);

    % Test 3: Rand-/fejltilfaelde med for lav indgrebsgrad.
    testName(3) = "Randtilfaelde: indgrebsgrad under 1.2";
    boundaryCase = calculateT1GearTrain( ...
        5, 5, 2, 20, 1000, +1, toothStandard, 1.20);
    testPassed(3) = ...
        boundaryCase.contactRatio < 1.20 && ...
        ~boundaryCase.allContactRatiosOK;
    testDetail(3) = sprintf( ...
        'mc = %.6f; forventet IKKE OK', boundaryCase.contactRatio);

    testTable = table(testName, testPassed, testDetail, ...
        'VariableNames', {'Test','Passed','Detail'});
    disp('Indbyggede regressionstests:')
    disp(testTable)

    results.courseTests = testTable;

    if all(testPassed)
        fprintf('OK - alle tre indbyggede tests bestod.\n');
    else
        error('T1:RegressionTestFailed', ...
            'Mindst én indbygget regressionstest fejlede.');
    end
end

%% LOCAL FUNCTIONS
function out = calculateT1GearTrain( ...
    zDrive, zDriven, moduleStage, pressureAngleDeg, ...
    inputSpeedRPM, inputDirection, toothStandard, minimumContactRatio)

    zDrive = zDrive(:).';
    zDriven = zDriven(:).';
    moduleStage = moduleStage(:).';
    pressureAngleDeg = pressureAngleDeg(:).';

    numberOfStages = numel(zDrive);

    driveGeometry = standardSpurGearGeometry( ...
        zDrive, moduleStage, pressureAngleDeg, toothStandard);
    drivenGeometry = standardSpurGearGeometry( ...
        zDriven, moduleStage, pressureAngleDeg, toothStandard);

    stageRatio = zDriven ./ zDrive;
    totalRatio = prod(stageRatio);

    shaftSpeedRPM = zeros(1, numberOfStages+1);
    shaftDirection = zeros(1, numberOfStages+1);
    shaftSpeedRPM(1) = inputSpeedRPM;
    shaftDirection(1) = inputDirection;

    for stageIndex = 1:numberOfStages
        shaftSpeedRPM(stageIndex+1) = ...
            shaftSpeedRPM(stageIndex) / stageRatio(stageIndex);
        shaftDirection(stageIndex+1) = -shaftDirection(stageIndex);
    end

    shaftOmegaRadPerSec = shaftSpeedRPM * 2*pi/60;
    signedShaftSpeedRPM = shaftSpeedRPM .* shaftDirection;
    signedShaftOmegaRadPerSec = ...
        shaftOmegaRadPerSec .* shaftDirection;

    centerDistanceMM = 0.5 * ( ...
        driveGeometry.pitchDiameterMM + ...
        drivenGeometry.pitchDiameterMM);

    driveRadicand = ...
        driveGeometry.addendumDiameterMM.^2 - ...
        driveGeometry.baseDiameterMM.^2;
    drivenRadicand = ...
        drivenGeometry.addendumDiameterMM.^2 - ...
        drivenGeometry.baseDiameterMM.^2;

    if any(driveRadicand < -1e-10) || any(drivenRadicand < -1e-10)
        error('T1:ImpossibleGeometry', ...
            'Tandtopcirklen ligger inden for grundcirklen.');
    end

    % Beskyt mod ganske smaa negative tal fra flydende komma.
    driveRadicand = max(driveRadicand, 0);
    drivenRadicand = max(drivenRadicand, 0);

    % Kursusformel:
    % L_ab = 0.5*(sqrt(da1^2-db1^2)+sqrt(da2^2-db2^2))
    %        - C*sin(phi)
    pathOfContactMM = 0.5 * ( ...
        sqrt(driveRadicand) + sqrt(drivenRadicand)) - ...
        centerDistanceMM .* sind(pressureAngleDeg);

    basePitchMM = pi * moduleStage .* cosd(pressureAngleDeg);
    contactRatio = pathOfContactMM ./ basePitchMM;

    if any(pathOfContactMM <= 0)
        error('T1:ImpossibleContactPath', ...
            'Indgrebsafstanden er ikke positiv. Kontrollér geometrien.');
    end

    out = struct;
    out.driveGeometry = driveGeometry;
    out.drivenGeometry = drivenGeometry;
    out.stageRatio = stageRatio;
    out.totalRatio = totalRatio;
    out.shaftSpeedRPM = shaftSpeedRPM;
    out.shaftOmegaRadPerSec = shaftOmegaRadPerSec;
    out.shaftDirection = shaftDirection;
    out.signedShaftSpeedRPM = signedShaftSpeedRPM;
    out.signedShaftOmegaRadPerSec = signedShaftOmegaRadPerSec;
    out.centerDistanceMM = centerDistanceMM;
    out.pathOfContactMM = pathOfContactMM;
    out.basePitchMM = basePitchMM;
    out.contactRatio = contactRatio;
    out.allContactRatiosOK = all(contactRatio >= minimumContactRatio);
end

function geometry = standardSpurGearGeometry( ...
    teeth, moduleMM, pressureAngleDeg, toothStandard)

    teeth = teeth(:).';
    moduleMM = moduleMM(:).';
    pressureAngleDeg = pressureAngleDeg(:).';

    pitchDiameterMM = teeth .* moduleMM;
    addendumMM = toothStandard.addendumFactor .* moduleMM;
    dedendumMM = toothStandard.dedendumFactor .* moduleMM;
    clearanceMM = toothStandard.clearanceFactor .* moduleMM;
    wholeDepthMM = addendumMM + dedendumMM;
    circularPitchMM = pi .* moduleMM;
    addendumDiameterMM = pitchDiameterMM + 2 .* addendumMM;
    rootDiameterMM = pitchDiameterMM - 2 .* dedendumMM;
    baseDiameterMM = pitchDiameterMM .* cosd(pressureAngleDeg);

    if any(rootDiameterMM <= 0)
        error('T1:NonPositiveRootDiameter', ...
            'Tandfodsdiameteren skal vaere positiv.');
    end

    geometry = struct;
    geometry.teeth = teeth;
    geometry.moduleMM = moduleMM;
    geometry.pressureAngleDeg = pressureAngleDeg;
    geometry.pitchDiameterMM = pitchDiameterMM;
    geometry.addendumMM = addendumMM;
    geometry.dedendumMM = dedendumMM;
    geometry.clearanceMM = clearanceMM;
    geometry.wholeDepthMM = wholeDepthMM;
    geometry.circularPitchMM = circularPitchMM;
    geometry.addendumDiameterMM = addendumDiameterMM;
    geometry.rootDiameterMM = rootDiameterMM;
    geometry.baseDiameterMM = baseDiameterMM;
end
