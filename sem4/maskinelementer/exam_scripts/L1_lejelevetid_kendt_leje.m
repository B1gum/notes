%% L1 - Lejelevetid for kendt leje
% Brug dette script naar:
%   Opgaven giver et kendt leje med dynamisk baeretal C samt radial- og
%   aksiallast og spoerger efter aekvivalent dynamisk belastning P,
%   L10 i millioner omdrejninger eller L10h i timer.
%
% Scriptet kan behandle:
%   1) separate_cases : Hver raekke er en selvstaendig opgave/lastretning.
%   2) duty_cycle     : Raekkerne er driftstilstande for det samme leje.
%
% Brug ikke dette script naar:
%   Lejet skal vaelges/dimensioneres ud fra en kraevet levetid (L2).
%
% Enheder:
%   C, C0, Fr, Fa og P : N
%   n                  : rpm
%   L10                : millioner omdrejninger
%   L10h               : timer
%
% VIGTIGT:
%   X, Y, e og f0 er katalogdata. Indtast vaerdierne fra den tabel, der
%   hoerer til det konkrete leje. Scriptet maa ikke bruges til at gaette dem.

clearvars
clc

%% INPUT

% Analyseform:
analysisMode = 'separate_cases';  % 'separate_cases' eller 'duty_cycle'

% Lejetype bestemmer levetidseksponenten:
bearingType = 'ball';             % 'ball' (p=3) eller 'roller' (p=10/3)

% Kendt leje - SKF 627 fra kursusopgaven
C_N  = 14.8e3;                    % [N] dynamisk baeretal
C0_N = 7.8e3;                    % [N] statisk baeretal, bruges ved opslag

% Hver raekke er et selvstaendigt lasttilfaelde i standardeksemplet.
caseNames = {
    '(a) Ren radiallast'
    '(b) Ren aksiallast'
    '(c) 45 graders last'
    };

Fr_N = [
    547.955
    783.618
    0
    ];

Fa_N = [
    101.079
    0
    0
    ];

n_rpm = 2900;                     % [rpm], skalar eller én vaerdi pr. raekke
V = 1.0;                          % [-] rotationsfaktor, skalar eller vektor

% Kun ved analysisMode = 'duty_cycle'.
% Andelene skal summe til 1; scriptet normaliserer dem IKKE automatisk.
timeShare = [];

% Metode til bestemmelse af P:
%   'lookup'   : e, X og Y findes fra tabellen nedenfor
%   'manual'   : e, X og Y indtastes direkte
%   'direct_P' : P er allerede fundet og indtastes direkte
factorMode = 'manual';

% Tabelopslag til SKF 627-opgaven. Opslagsparameter = f0*Fa/C0.
f0 = 14;
lookupParameterTable = [0.172; 0.345; 0.689; 1.03; 1.38; 2.07; 3.45; 5.17; 6.89];
eTable =               [0.19;  0.22;  0.26;  0.28; 0.30; 0.34; 0.38; 0.42; 0.44];
XTable = 0.56;                    % skalar eller kolonne med samme laengde som tabellen
YTable =               [2.30;  1.99;  1.71;  1.55; 1.45; 1.31; 1.15; 1.04; 1.00];
allowExtrapolation = false;

% Kun ved factorMode = 'manual'. Skalarer udvides til alle raekker.
eManual = 0.19;
XManual = 0.56;
YManual = 2.3;

% Kun ved factorMode = 'direct_P'.
Pdirect_N = [];

% Eventuelt krav. Brug NaN, hvis der ikke skal kontrolleres et krav.
requiredLife_h = NaN;

% Praktiske valg
makeDamagePlot = false;           % kun relevant for duty_cycle
saveResult = false;

%% FORVENTEDE RESULTATER FOR STANDARDINPUTTET
% Kursusopgaven med SKF 627 giver ved lineaer interpolation:
%   (a) P = 500.000 N, L10 = 328.509 mio. omdr., L10h = 1887.983 h
%   (b) P = 545.276 N, L10 = 253.285 mio. omdr., L10h = 1455.659 h
%   (c) P = 619.054 N, L10 = 173.090 mio. omdr., L10h =  994.770 h

%% KONTROL OG KLARGOERING AF INPUT

analysisMode = lower(strtrim(analysisMode));
factorMode = lower(strtrim(factorMode));

switch lower(strtrim(bearingType))
    case {'ball','kugle','kugleleje'}
        p = 3;
        bearingTypeText = 'Kugleleje';
    case {'roller','rulle','rulleleje'}
        p = 10/3;
        bearingTypeText = 'Rulleleje';
    otherwise
        error('Ukendt bearingType. Brug ''ball'' eller ''roller''.')
end

assert(isfinite(C_N) && C_N > 0, ...
    'Det dynamiske baeretal C skal vaere positivt.')

if strcmp(factorMode,'direct_p')
    N = numel(Pdirect_N);
    assert(N >= 1, ...
        'Pdirect_N skal indeholde mindst én vaerdi ved direct_P.')
else
    N = max([numel(Fr_N), numel(Fa_N), numel(n_rpm), numel(V)]);
end

caseNames = expandNames(caseNames,N);
n_rpm = expandNumeric(n_rpm,N,'n_rpm');
V = expandNumeric(V,N,'V');

assert(all(isfinite(n_rpm) & n_rpm >= 0), ...
    'Alle omdrejningstal skal vaere endelige og ikke-negative.')
assert(all(isfinite(V) & V > 0), ...
    'Alle rotationsfaktorer V skal vaere positive.')

%% AEKVIVALENT DYNAMISK BELASTNING P

lookupParameter = nan(N,1);
ratioFaVFr = nan(N,1);
eApplied = nan(N,1);
XApplied = nan(N,1);
YApplied = nan(N,1);
loadRule = cell(N,1);

if strcmp(factorMode,'direct_p')
    P_N = expandNumeric(Pdirect_N,N,'Pdirect_N');
    assert(all(isfinite(P_N) & P_N >= 0), ...
        'Alle direkte P-vaerdier skal vaere ikke-negative.')

    Fr_N = nan(N,1);
    Fa_N = nan(N,1);
    loadRule(:) = {'P angivet direkte'};

else
    Fr_N = expandNumeric(Fr_N,N,'Fr_N');
    Fa_N = expandNumeric(Fa_N,N,'Fa_N');

    assert(all(isfinite(Fr_N) & Fr_N >= 0), ...
        'Alle radialkraefter Fr skal vaere ikke-negative.')
    assert(all(isfinite(Fa_N) & Fa_N >= 0), ...
        'Alle aksialkraefter Fa skal vaere ikke-negative.')

    hasRadialLoad = Fr_N > 0;
    ratioFaVFr(hasRadialLoad) = ...
        Fa_N(hasRadialLoad)./(V(hasRadialLoad).*Fr_N(hasRadialLoad));
    ratioFaVFr(~hasRadialLoad & Fa_N > 0) = Inf;
    ratioFaVFr(Fr_N == 0 & Fa_N == 0) = 0;

    switch factorMode
        case 'lookup'
            assert(isfinite(C0_N) && C0_N > 0, ...
                'C0 skal vaere positivt ved tabelopslag.')
            assert(isfinite(f0) && f0 >= 0, ...
                'f0 skal vaere ikke-negativ.')

            t = lookupParameterTable(:);
            eTab = eTable(:);
            YTab = YTable(:);

            assert(numel(t) >= 2 && numel(eTab) == numel(t) ...
                && numel(YTab) == numel(t), ...
                'Opslagstabellens parameter, e og Y skal have samme laengde.')
            assert(all(isfinite(t)) && all(diff(t) > 0), ...
                'Opslagsparameteren skal vaere strengt voksende.')

            lookupParameter = f0.*Fa_N./C0_N;
            needsLookup = Fa_N > 0;

            if ~allowExtrapolation
                outsideTable = needsLookup & ...
                    (lookupParameter < t(1) | lookupParameter > t(end));
                if any(outsideTable)
                    error(['Mindst én vaerdi af f0*Fa/C0 ligger uden for tabellen. ' ...
                        'Indtast korrekte katalogdata; ekstrapoler ikke skjult.'])
                end
            end

            if allowExtrapolation
                eApplied(needsLookup) = interp1(t,eTab, ...
                    lookupParameter(needsLookup),'linear','extrap');
                YApplied(needsLookup) = interp1(t,YTab, ...
                    lookupParameter(needsLookup),'linear','extrap');
            else
                eApplied(needsLookup) = interp1(t,eTab, ...
                    lookupParameter(needsLookup),'linear');
                YApplied(needsLookup) = interp1(t,YTab, ...
                    lookupParameter(needsLookup),'linear');
            end

            if isscalar(XTable)
                XApplied(needsLookup) = XTable;
            else
                XTab = XTable(:);
                assert(numel(XTab) == numel(t), ...
                    'XTable skal vaere en skalar eller have samme laengde som tabellen.')
                if allowExtrapolation
                    XApplied(needsLookup) = interp1(t,XTab, ...
                        lookupParameter(needsLookup),'linear','extrap');
                else
                    XApplied(needsLookup) = interp1(t,XTab, ...
                        lookupParameter(needsLookup),'linear');
                end
            end

        case 'manual'
            eApplied = expandNumeric(eManual,N,'eManual');
            XApplied = expandNumeric(XManual,N,'XManual');
            YApplied = expandNumeric(YManual,N,'YManual');

        otherwise
            error('Ukendt factorMode. Brug lookup, manual eller direct_P.')
    end

    % Hvis Fa/(V*Fr) <= e, anvendes P = V*Fr.
    radialRule = (Fa_N == 0) | (ratioFaVFr <= eApplied);

    XApplied(radialRule) = 1;
    YApplied(radialRule) = 0;
    eApplied(Fa_N == 0) = NaN;    % intet tabelopslag er noedvendigt

    P_N = XApplied.*V.*Fr_N + YApplied.*Fa_N;

    loadRule(:) = {'P = X*V*Fr + Y*Fa'};
    loadRule(radialRule) = {'P = V*Fr'};
end

assert(all(isfinite(P_N) & P_N >= 0), ...
    'Den beregnede aekvivalente belastning P er ugyldig.')

%% LEVETID FOR HVER RAEKKE

% Grundlevetid ved 90 procent overlevelsessandsynlighed:
%   L10  = (C/P)^p                  [millioner omdrejninger]
%   L10h = 10^6/(60*n)*(C/P)^p     [timer]

L10_Mrev = inf(N,1);
loaded = P_N > 0;
L10_Mrev(loaded) = (C_N./P_N(loaded)).^p;

L10h = inf(N,1);
rotatingAndLoaded = n_rpm > 0 & loaded;
L10h(rotatingAndLoaded) = 1e6./(60*n_rpm(rotatingAndLoaded)) ...
    .* L10_Mrev(rotatingAndLoaded);

%% SAMLET LEVETID VED VARIERENDE LAST

timeShareColumn = nan(N,1);
damageRate_per_h = nan(N,1);
damagePercent = nan(N,1);
P_equiv_N = NaN;
n_equiv_rpm = NaN;
L10_equiv_Mrev = NaN;
L10h_total = NaN;

switch analysisMode
    case 'separate_cases'
        % Hver raekke er en selvstaendig beregning; ingen summering.

    case 'duty_cycle'
        timeShareColumn = expandNumeric(timeShare,N,'timeShare');
        assert(all(isfinite(timeShareColumn) & timeShareColumn >= 0), ...
            'Alle timeandele skal vaere ikke-negative.')

        shareSum = sum(timeShareColumn);
        assert(abs(shareSum-1) <= 1e-8, ...
            ['Timeandelene skal summe til 1. Scriptet normaliserer dem ' ...
             'ikke automatisk.'])

        % Skade pr. driftstime fra hver tilstand.
        damageRate_per_h = timeShareColumn.*(60*n_rpm/1e6) ...
            .*(P_N/C_N).^p;
        totalDamageRate_per_h = sum(damageRate_per_h);

        if totalDamageRate_per_h > 0
            L10h_total = 1/totalDamageRate_per_h;
            damagePercent = 100*damageRate_per_h/totalDamageRate_per_h;
        else
            L10h_total = Inf;
            damagePercent = zeros(N,1);
        end

        % Samme resultat udtrykt ved aekvivalent hastighed og belastning.
        n_equiv_rpm = sum(timeShareColumn.*n_rpm);
        if n_equiv_rpm > 0
            P_equiv_N = (sum(timeShareColumn.*n_rpm.*P_N.^p) ...
                /n_equiv_rpm)^(1/p);
            if P_equiv_N > 0
                L10_equiv_Mrev = (C_N/P_equiv_N)^p;
            else
                L10_equiv_Mrev = Inf;
            end
        else
            P_equiv_N = 0;
            L10_equiv_Mrev = Inf;
        end

    otherwise
        error('Ukendt analysisMode. Brug separate_cases eller duty_cycle.')
end

%% RESULTATTABEL

caseNumber = (1:N)';
resultTable = table( ...
    caseNumber,caseNames,timeShareColumn,Fr_N,Fa_N,n_rpm,V, ...
    lookupParameter,ratioFaVFr,eApplied,XApplied,YApplied,P_N, ...
    L10_Mrev,L10h,damagePercent,loadRule, ...
    'VariableNames',{ ...
    'CaseNo','CaseName','TimeShare','Fr_N','Fa_N','n_rpm','V', ...
    'LookupParameter','Fa_over_VFr','e','X','Y','P_N', ...
    'L10_Mrev','L10h','DamagePercent','LoadRule'});

disp(resultTable)

%% TYDELIG UDSKRIFT

fprintf('\n============================================================\n')
fprintf('L1 - LEJELEVETID FOR KENDT LEJE\n')
fprintf('============================================================\n')
fprintf('Lejetype:             %s\n',bearingTypeText)
fprintf('Eksponent p:          %.6g\n',p)
fprintf('Dynamisk baeretal C:  %.3f N\n',C_N)
fprintf('Analyseform:          %s\n',analysisMode)

for i = 1:N
    fprintf('\nTilfaelde %d: %s\n',i,caseNames{i})
    fprintf('  Regel:              %s\n',loadRule{i})
    fprintf('  P:                  %.6f N\n',P_N(i))
    fprintf('  L10:                %.6f mio. omdr.\n',L10_Mrev(i))
    fprintf('  L10h:               %.6f h\n',L10h(i))

    if isfinite(requiredLife_h)
        if L10h(i) >= requiredLife_h
            fprintf('  OK: Levetidskravet paa %.3f h er opfyldt.\n',requiredLife_h)
        else
            fprintf('  ADVARSEL: Levetidskravet paa %.3f h er IKKE opfyldt.\n', ...
                requiredLife_h)
        end
    end
end

if strcmp(analysisMode,'duty_cycle')
    fprintf('\nSAMLET DRIFTSCYKLUS\n')
    fprintf('  Aekvivalent n:      %.6f rpm\n',n_equiv_rpm)
    fprintf('  Aekvivalent P:      %.6f N\n',P_equiv_N)
    fprintf('  Samlet L10:         %.6f mio. omdr.\n',L10_equiv_Mrev)
    fprintf('  Samlet L10h:        %.6f h\n',L10h_total)

    if isfinite(requiredLife_h)
        if L10h_total >= requiredLife_h
            fprintf('  OK: Den samlede driftscyklus opfylder levetidskravet.\n')
        else
            fprintf('  ADVARSEL: Driftscyklussen opfylder IKKE levetidskravet.\n')
        end
    end
end
fprintf('============================================================\n')

%% RESULTATER SOM STRUCT

resultat = struct;
resultat.lejetype = bearingTypeText;
resultat.p = p;
resultat.C_N = C_N;
resultat.C0_N = C0_N;
resultat.caseNames = caseNames;
resultat.P_N = P_N;
resultat.L10_Mrev = L10_Mrev;
resultat.L10h = L10h;
resultat.e = eApplied;
resultat.X = XApplied;
resultat.Y = YApplied;
resultat.lookupParameter = lookupParameter;
resultat.timeShare = timeShareColumn;
resultat.damagePercent = damagePercent;
resultat.P_equiv_N = P_equiv_N;
resultat.n_equiv_rpm = n_equiv_rpm;
resultat.L10_equiv_Mrev = L10_equiv_Mrev;
resultat.L10h_total = L10h_total;
resultat.table = resultTable;

if makeDamagePlot && strcmp(analysisMode,'duty_cycle')
    figure
    bar(damagePercent)
    grid on
    ylabel('Andel af samlet lejeskade [%]')
    xlabel('Driftstilstand')
    title('Skadebidrag fra driftstilstandene')
    xticks(1:N)
    xticklabels(caseNames)
    xtickangle(20)
end

if saveResult
    save('L1_resultat.mat','resultat')
end

%% LOKALE HJAELPEFUNKTIONER

function y = expandNumeric(x,N,name)
% Udvider en skalar eller kontrollerer, at en vektor har N elementer.
    assert(~isempty(x),'%s maa ikke vaere tom.',name)
    x = x(:);
    if isscalar(x)
        y = repmat(x,N,1);
    elseif numel(x) == N
        y = x;
    else
        error('%s skal vaere en skalar eller have %d elementer.',name,N)
    end
end

function names = expandNames(inputNames,N)
% Giver en cellekolonne med ét navn pr. beregningsraekke.
    if isempty(inputNames)
        names = arrayfun(@(k) sprintf('Tilfaelde %d',k), ...
            (1:N)','UniformOutput',false);
        return
    end

    if isstring(inputNames)
        names = cellstr(inputNames(:));
    elseif ischar(inputNames)
        names = {inputNames};
    elseif iscell(inputNames)
        names = inputNames(:);
    else
        error('caseNames skal vaere tekst, string-array eller cell-array.')
    end

    if numel(names) == 1 && N > 1
        baseName = char(names{1});
        names = arrayfun(@(k) sprintf('%s %d',baseName,k), ...
            (1:N)','UniformOutput',false);
    elseif numel(names) ~= N
        error('caseNames skal have 1 eller %d elementer.',N)
    end

    names = cellfun(@char,names,'UniformOutput',false);
end
