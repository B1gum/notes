%% L2 - Valg eller dimensionering af leje
% Brug dette script naar:
%   Opgaven giver belastning, omdrejningstal og kraevet levetid og spoerger
%   efter noedvendigt dynamisk baeretal C eller et muligt leje fra et
%   lokalt katalog.
%
% Scriptet kan:
%   1) beregne noedvendigt dynamisk baeretal C_req,
%   2) beregne eventuelt noedvendigt statisk baeretal C0_req,
%   3) kontrollere huldiameter, lejetype og graenseomdrejningstal,
%   4) filtrere mulige lejer fra en lokal tabel,
%   5) behandle en enkelt belastning eller en tidsvarierende driftscyklus,
%   6) beregne P direkte, med manuelt indtastede X/Y/e eller kandidatvist
%      fra C0, f0 og en lokal e/Y-tabel.
%
% Brug ikke dette script naar:
%   Lejet allerede er kendt, og levetiden alene skal beregnes. Brug L1.
%
% Grundformler:
%   L10  = (C/P)^p                                         [mio. omdr.]
%   L10h = 10^6/(60*n)*(C/P)^p                            [h]
%   C_req = P*(60*n*L10h/10^6)^(1/p)                      [N]
%
% Ved varierende last:
%   C_req = [60*L_req/10^6 * sum(q_i*n_i*P_i^p)]^(1/p)
%
% Enheder:
%   Kraefter og baeretal : N
%   Diametre             : mm
%   Omdrejningstal       : rpm
%   Levetid              : timer
%
% VIGTIGT:
%   Katalogdata, X, Y, e, f0, statisk sikkerhedsfaktor s0 og eventuelle
%   belastningsfaktorer skal komme fra opgaven eller et relevant katalog.
%   Scriptet maa ikke bruges til at gaette disse vaerdier.

clearvars
clc

%% INPUT - OPGAVE OG DRIFT

% Lejetype bestemmer levetidseksponenten.
bearingType = 'ball';                 % 'ball' eller 'roller'

% Kraevet grundlevetid L10h.
requiredLife_h = 1887.98275862069;     % [h]

% Krav til huldiameter. Brug NaN, hvis diameteren ikke skal filtreres.
requiredBore_mm = 7;                   % [mm]
boreTolerance_mm = 0;                  % [mm]

% Hver raekke beskriver én driftstilstand for det samme leje.
stateNames = {
    'Kursusopgave (a), dimensioneret baglaens'
    };

n_rpm = 2900;                          % [rpm], skalar eller én pr. tilstand
timeShare = 1.0;                       % [-], skal summe til 1

% Belastningsmetode:
%   'direct_P'         : P er allerede beregnet og indtastes direkte.
%   'manual_factors'   : P beregnes fra Fr, Fa, V samt manuelle X, Y og e.
%   'candidate_lookup' : P beregnes for hvert katalogleje ud fra lejets
%                        C0 og f0 samt e/Y-tabellen nedenfor.
loadMode = 'direct_P';

% Belastningsfaktor, der multipliceres paa den dynamiske belastning P.
% Brug kun en anden vaerdi end 1, hvis opgaven foreskriver det.
dynamicLoadFactor = 1.0;               % skalar eller én pr. tilstand

% Kun ved loadMode = 'direct_P'.
Pdirect_N = 500;                       % [N]

% Kun ved loadMode = 'manual_factors' eller 'candidate_lookup'.
Fr_N = 500;                            % [N]
Fa_N = 0;                              % [N]
V = 1.0;                               % [-], rotationsfaktor

% Kun ved loadMode = 'manual_factors'.
eManual = 0.30;                        % [-]
XManual = 0.56;                        % [-]
YManual = 1.45;                        % [-]

%% INPUT - STATISK KONTROL

checkStatic = true;

% Statisk metode:
%   'direct_P0'       : den statiske aekvivalentbelastning P0 indtastes.
%   'manual_factors'  : P0 = X0*Fr + Y0*Fa, eventuelt mindst Fr.
staticLoadMode = 'direct_P0';

% Kun ved staticLoadMode = 'direct_P0'.
P0direct_N = 500;                      % [N], skalar eller én pr. tilstand

% Kun ved staticLoadMode = 'manual_factors'.
X0 = 0.60;                             % [-], katalog-/opgavedata
Y0 = 0.50;                             % [-], katalog-/opgavedata
enforceP0atLeastFr = true;

% Statisk sikkerhedsfaktor. Vaelges fra opgaven/anvendelsen.
s0_required = 1.0;                    % [-]
staticLoadFactor = 1.0;                % skalar eller én pr. tilstand

%% INPUT - LOKAL LEJETABEL
% Tilfoej flere rækker direkte fra det relevante katalog.
% NaN kan bruges for ukendt graenseomdrejningstal; saa kontrolleres det ikke.
%
% Standardraekken er SKF 627 fra kursusopgaven, som ogsaa blev brugt i L1.

catalog = table( ...
    {'SKF 627'}', ...                  % designation
    {'ball'}', ...                     % type
    7, ...                             % d [mm]
    22, ...                            % D [mm]
    7, ...                             % B [mm]
    3.45e3, ...                        % C [N]
    1.37e3, ...                        % C0 [N]
    12, ...                            % f0 [-]
    NaN, ...                           % n_lim [rpm]
    'VariableNames',{ ...
    'Designation','Type','d_mm','D_mm','B_mm','C_N','C0_N','f0','n_lim_rpm'});

%% INPUT - TABEL TIL KANDIDATVIST OPSLAG
% Tabellen nedenfor stammer fra den samme SKF 627-kursusopgave som L1.
% Udskift tabellen, hvis opgaven eller lejetypen bruger andre katalogdata.

lookupParameterTable = [0.172; 0.345; 0.689; 1.03; 1.38; 2.07; 3.45; 5.17; 6.89];
eTable =               [0.19;  0.22;  0.26;  0.28; 0.30; 0.34; 0.38; 0.42; 0.44];
XLookup = 0.56;                     % skalar eller én vaerdi pr. tabelraekke
YTable =               [2.30;  1.99;  1.71;  1.55; 1.45; 1.31; 1.15; 1.04; 1.00];
allowExtrapolation = false;

%% PRAKTISKE VALG

runSelfTests = true;
saveResult = false;

%% FORVENTET RESULTAT FOR STANDARDINPUTTET
% Kursusopgaven kontrolleres baglaens:
%   P = 500 N, n = 2900 rpm og L10h = 1887.98275862 h
%   giver C_req = 3450 N.
% Den lokale tabel skal derfor vaelge SKF 627.

%% KONTROL OG KLARGOERING AF INPUT

loadMode = lower(strtrim(loadMode));
staticLoadMode = lower(strtrim(staticLoadMode));

switch lower(strtrim(bearingType))
    case {'ball','kugle','kugleleje'}
        p = 3;
        bearingTypeKey = 'ball';
        bearingTypeText = 'Kugleleje';
    case {'roller','rulle','rulleleje'}
        p = 10/3;
        bearingTypeKey = 'roller';
        bearingTypeText = 'Rulleleje';
    otherwise
        error('Ukendt bearingType. Brug ''ball'' eller ''roller''.')
end

assert(isfinite(requiredLife_h) && requiredLife_h > 0, ...
    'requiredLife_h skal vaere positiv.')
assert(isfinite(boreTolerance_mm) && boreTolerance_mm >= 0, ...
    'boreTolerance_mm skal vaere ikke-negativ.')
assert(isfinite(s0_required) && s0_required > 0, ...
    's0_required skal vaere positiv.')

switch loadMode
    case 'direct_p'
        N = max([numel(Pdirect_N),numel(n_rpm),numel(timeShare), ...
            numel(dynamicLoadFactor)]);
    case {'manual_factors','candidate_lookup'}
        N = max([numel(Fr_N),numel(Fa_N),numel(V),numel(n_rpm), ...
            numel(timeShare),numel(dynamicLoadFactor)]);
    otherwise
        error(['Ukendt loadMode. Brug direct_P, manual_factors ' ...
            'eller candidate_lookup.'])
end

% Statisk input kan indeholde flere driftstilstande end det dynamiske input.
if checkStatic
    switch staticLoadMode
        case 'direct_p0'
            N = max([N,numel(P0direct_N),numel(staticLoadFactor)]);
        case 'manual_factors'
            N = max([N,numel(Fr_N),numel(Fa_N),numel(V), ...
                numel(staticLoadFactor)]);
        otherwise
            error('Ukendt staticLoadMode. Brug direct_P0 eller manual_factors.')
    end
end

stateNames = expandNames(stateNames,N);
n_rpm = expandNumeric(n_rpm,N,'n_rpm');
timeShare = expandNumeric(timeShare,N,'timeShare');
dynamicLoadFactor = expandNumeric(dynamicLoadFactor,N,'dynamicLoadFactor');

assert(all(isfinite(n_rpm) & n_rpm >= 0), ...
    'Alle omdrejningstal skal vaere endelige og ikke-negative.')
assert(all(isfinite(timeShare) & timeShare >= 0), ...
    'Alle tidsandele skal vaere ikke-negative.')
assert(abs(sum(timeShare)-1) <= 1e-8, ...
    'Tidsandelene skal summe til 1; de normaliseres ikke automatisk.')
assert(all(isfinite(dynamicLoadFactor) & dynamicLoadFactor > 0), ...
    'dynamicLoadFactor skal vaere positiv.')

% Kontroller katalogets opbygning.
requiredCatalogVariables = { ...
    'Designation','Type','d_mm','D_mm','B_mm','C_N','C0_N','f0','n_lim_rpm'};
missingVariables = setdiff(requiredCatalogVariables,catalog.Properties.VariableNames);
assert(isempty(missingVariables), ...
    'Katalogtabellen mangler: %s',strjoin(missingVariables,', '))

M = height(catalog);
assert(all(isfinite(catalog.C_N) & catalog.C_N > 0), ...
    'Alle katalogets C-vaerdier skal vaere positive.')
assert(all(isfinite(catalog.C0_N) & catalog.C0_N > 0), ...
    'Alle katalogets C0-vaerdier skal vaere positive.')
assert(all(isfinite(catalog.d_mm) & catalog.d_mm > 0), ...
    'Alle katalogets huldiametre skal vaere positive.')

catalogTypeKey = normalizeTypeColumn(catalog.Type);

%% BEREGN DYNAMISK AEKVIVALENTBELASTNING P

FrWork_N = nan(N,1);
FaWork_N = nan(N,1);
VWork = nan(N,1);
ratioFaVFr = nan(N,1);
loadRuleCommon = repmat({''},N,1);
Pcommon_N = nan(N,1);

% Ved kandidatvist opslag bliver P en N x M-matrice.
P_by_candidate_N = nan(N,M);
e_by_candidate = nan(N,M);
Y_by_candidate = nan(N,M);
lookupParameter_by_candidate = nan(N,M);
lookupValid = true(M,1);

switch loadMode
    case 'direct_p'
        Pcommon_N = expandNumeric(Pdirect_N,N,'Pdirect_N');
        assert(all(isfinite(Pcommon_N) & Pcommon_N >= 0), ...
            'Pdirect_N skal vaere ikke-negativ.')
        Pcommon_N = dynamicLoadFactor.*Pcommon_N;
        loadRuleCommon(:) = {'P angivet direkte'};

        % Fr, Fa og V er ikke noedvendige i direct_P, men vises hvis de er
        % udfyldt. De kan ogsaa bruges af den statiske kontrol.
        if ~isempty(Fr_N) && ~isempty(Fa_N) && ~isempty(V)
            FrWork_N = expandNumeric(Fr_N,N,'Fr_N');
            FaWork_N = expandNumeric(Fa_N,N,'Fa_N');
            VWork = expandNumeric(V,N,'V');
            validateLoads(FrWork_N,FaWork_N,VWork)
            ratioFaVFr = forceRatio(FaWork_N,VWork,FrWork_N);
        end

        if M > 0
            P_by_candidate_N = repmat(Pcommon_N,1,M);
        end

    case 'manual_factors'
        FrWork_N = expandNumeric(Fr_N,N,'Fr_N');
        FaWork_N = expandNumeric(Fa_N,N,'Fa_N');
        VWork = expandNumeric(V,N,'V');
        eApplied = expandNumeric(eManual,N,'eManual');
        XApplied = expandNumeric(XManual,N,'XManual');
        YApplied = expandNumeric(YManual,N,'YManual');

        validateLoads(FrWork_N,FaWork_N,VWork)
        ratioFaVFr = forceRatio(FaWork_N,VWork,FrWork_N);

        radialRule = (FaWork_N == 0) | (ratioFaVFr <= eApplied);
        XApplied(radialRule) = 1;
        YApplied(radialRule) = 0;

        Pcommon_N = dynamicLoadFactor.*( ...
            XApplied.*VWork.*FrWork_N + YApplied.*FaWork_N);

        loadRuleCommon(:) = {'P = X*V*Fr + Y*Fa'};
        loadRuleCommon(radialRule) = {'P = V*Fr'};

        if M > 0
            P_by_candidate_N = repmat(Pcommon_N,1,M);
        end

    case 'candidate_lookup'
        FrWork_N = expandNumeric(Fr_N,N,'Fr_N');
        FaWork_N = expandNumeric(Fa_N,N,'Fa_N');
        VWork = expandNumeric(V,N,'V');
        validateLoads(FrWork_N,FaWork_N,VWork)
        ratioFaVFr = forceRatio(FaWork_N,VWork,FrWork_N);

        t = lookupParameterTable(:);
        eTab = eTable(:);
        YTab = YTable(:);
        assert(numel(t) >= 2 && numel(eTab) == numel(t) ...
            && numel(YTab) == numel(t), ...
            'Opslagsparameter, e og Y skal have samme laengde.')
        assert(all(isfinite(t)) && all(diff(t) > 0), ...
            'Opslagsparameteren skal vaere strengt voksende.')

        if isscalar(XLookup)
            XTab = repmat(XLookup,numel(t),1);
        else
            XTab = XLookup(:);
            assert(numel(XTab) == numel(t), ...
                'XLookup skal vaere skalar eller have samme laengde som tabellen.')
        end

        for j = 1:M
            Pj = nan(N,1);
            ej = nan(N,1);
            Xj = nan(N,1);
            Yj = nan(N,1);

            radialOnly = FaWork_N == 0;
            Pj(radialOnly) = dynamicLoadFactor(radialOnly).* ...
                VWork(radialOnly).*FrWork_N(radialOnly);
            Xj(radialOnly) = 1;
            Yj(radialOnly) = 0;

            needsLookup = FaWork_N > 0;
            if any(needsLookup)
                if ~(isfinite(catalog.C0_N(j)) && catalog.C0_N(j) > 0 ...
                        && isfinite(catalog.f0(j)) && catalog.f0(j) >= 0)
                    lookupValid(j) = false;
                    continue
                end

                lookupParameter_by_candidate(needsLookup,j) = ...
                    catalog.f0(j).*FaWork_N(needsLookup)./catalog.C0_N(j);
                q = lookupParameter_by_candidate(needsLookup,j);

                if ~allowExtrapolation && any(q < t(1) | q > t(end))
                    lookupValid(j) = false;
                    continue
                end

                if allowExtrapolation
                    ej(needsLookup) = interp1(t,eTab,q,'linear','extrap');
                    Xj(needsLookup) = interp1(t,XTab,q,'linear','extrap');
                    Yj(needsLookup) = interp1(t,YTab,q,'linear','extrap');
                else
                    ej(needsLookup) = interp1(t,eTab,q,'linear');
                    Xj(needsLookup) = interp1(t,XTab,q,'linear');
                    Yj(needsLookup) = interp1(t,YTab,q,'linear');
                end

                radialRule = needsLookup & (ratioFaVFr <= ej);
                Xj(radialRule) = 1;
                Yj(radialRule) = 0;

                Pj(needsLookup) = dynamicLoadFactor(needsLookup).* ...
                    (Xj(needsLookup).*VWork(needsLookup).*FrWork_N(needsLookup) ...
                    + Yj(needsLookup).*FaWork_N(needsLookup));
            end

            if any(~isfinite(Pj) | Pj < 0)
                lookupValid(j) = false;
            else
                P_by_candidate_N(:,j) = Pj;
                e_by_candidate(:,j) = ej;
                Y_by_candidate(:,j) = Yj;
            end
        end
end

%% NOEDVENDIGT DYNAMISK BAERETAL

n_equiv_rpm = sum(timeShare.*n_rpm);
requiredL10_Mrev = 60*n_equiv_rpm*requiredLife_h/1e6;

if strcmp(loadMode,'candidate_lookup')
    C_required_by_candidate_N = nan(M,1);
    P_equiv_by_candidate_N = nan(M,1);

    for j = 1:M
        if lookupValid(j)
            C_required_by_candidate_N(j) = requiredDynamicRating( ...
                P_by_candidate_N(:,j),n_rpm,timeShare,requiredLife_h,p);
            P_equiv_by_candidate_N(j) = equivalentDynamicLoad( ...
                P_by_candidate_N(:,j),n_rpm,timeShare,p);
        end
    end

    C_required_N = NaN;               % kandidat-afhaengigt i denne metode
    P_equiv_N = NaN;
else
    C_required_N = requiredDynamicRating( ...
        Pcommon_N,n_rpm,timeShare,requiredLife_h,p);
    P_equiv_N = equivalentDynamicLoad( ...
        Pcommon_N,n_rpm,timeShare,p);

    C_required_by_candidate_N = repmat(C_required_N,M,1);
    P_equiv_by_candidate_N = repmat(P_equiv_N,M,1);
end

%% NOEDVENDIGT STATISK BAERETAL

P0_N = nan(N,1);
P0_max_N = NaN;
C0_required_N = NaN;

if checkStatic
    staticLoadFactor = expandNumeric(staticLoadFactor,N,'staticLoadFactor');
    assert(all(isfinite(staticLoadFactor) & staticLoadFactor > 0), ...
        'staticLoadFactor skal vaere positiv.')

    switch staticLoadMode
        case 'direct_p0'
            P0_N = expandNumeric(P0direct_N,N,'P0direct_N');
            assert(all(isfinite(P0_N) & P0_N >= 0), ...
                'P0direct_N skal vaere ikke-negativ.')

        case 'manual_factors'
            if all(isnan(FrWork_N))
                FrWork_N = expandNumeric(Fr_N,N,'Fr_N');
                FaWork_N = expandNumeric(Fa_N,N,'Fa_N');
                VWork = expandNumeric(V,N,'V');
                validateLoads(FrWork_N,FaWork_N,VWork)
            end

            P0_N = X0.*FrWork_N + Y0.*FaWork_N;
            if enforceP0atLeastFr
                P0_N = max(P0_N,FrWork_N);
            end

        otherwise
            error('Ukendt staticLoadMode. Brug direct_P0 eller manual_factors.')
    end

    P0_N = staticLoadFactor.*P0_N;
    P0_max_N = max(P0_N);
    C0_required_N = s0_required*P0_max_N;
end

%% KONTROL AF KATALOGKANDIDATER

if M > 0
    typePass = strcmp(catalogTypeKey,bearingTypeKey);

    if isnan(requiredBore_mm)
        borePass = true(M,1);
    else
        borePass = abs(catalog.d_mm-requiredBore_mm) <= boreTolerance_mm;
    end

    dynamicTolerance_N = 1e-9*max(1,C_required_by_candidate_N);
    dynamicPass = isfinite(C_required_by_candidate_N) & ...
        (catalog.C_N + dynamicTolerance_N >= C_required_by_candidate_N);

    if checkStatic
        staticPass = catalog.C0_N + 1e-9*max(1,C0_required_N) >= C0_required_N;
    else
        staticPass = true(M,1);
    end

    maxSpeed_rpm = max(n_rpm);
    speedPass = isnan(catalog.n_lim_rpm) | catalog.n_lim_rpm >= maxSpeed_rpm;

    if strcmp(loadMode,'candidate_lookup')
        factorPass = lookupValid;
    else
        factorPass = true(M,1);
    end

    passesAll = typePass & borePass & dynamicPass & staticPass & speedPass & factorPass;

    predictedLife_h = nan(M,1);
    lifeMargin = nan(M,1);
    dynamicReserve = nan(M,1);
    staticReserve = nan(M,1);

    for j = 1:M
        if factorPass(j)
            predictedLife_h(j) = bearingLifeHours( ...
                catalog.C_N(j),P_by_candidate_N(:,j),n_rpm,timeShare,p);
            lifeMargin(j) = predictedLife_h(j)/requiredLife_h;
            dynamicReserve(j) = catalog.C_N(j)/C_required_by_candidate_N(j);
        end
    end

    if checkStatic
        staticReserve = catalog.C0_N/C0_required_N;
    end

    failureReason = repmat({''},M,1);
    failureReason = appendFailure(failureReason,~typePass,'forkert lejetype');
    failureReason = appendFailure(failureReason,~borePass,'forkert huldiameter');
    failureReason = appendFailure(failureReason,~factorPass,'manglende/ugyldigt faktoropslag');
    failureReason = appendFailure(failureReason,~dynamicPass,'C for lille');
    failureReason = appendFailure(failureReason,~staticPass,'C0 for lille');
    failureReason = appendFailure(failureReason,~speedPass,'omdrejningstal for hoejt');
    failureReason(passesAll) = {'OK'};

    candidateTable = catalog;
    candidateTable.P_equiv_N = P_equiv_by_candidate_N;
    candidateTable.C_required_N = C_required_by_candidate_N;
    candidateTable.C0_required_N = repmat(C0_required_N,M,1);
    candidateTable.PredictedLife_h = predictedLife_h;
    candidateTable.LifeMargin = lifeMargin;
    candidateTable.DynamicReserve = dynamicReserve;
    candidateTable.StaticReserve = staticReserve;
    candidateTable.TypePass = typePass;
    candidateTable.BorePass = borePass;
    candidateTable.FactorPass = factorPass;
    candidateTable.DynamicPass = dynamicPass;
    candidateTable.StaticPass = staticPass;
    candidateTable.SpeedPass = speedPass;
    candidateTable.PassesAll = passesAll;
    candidateTable.Status = failureReason;

    possibleBearings = candidateTable(passesAll,:);
    if ~isempty(possibleBearings)
        possibleBearings = sortrows(possibleBearings,{'C_N','B_mm'});
    end
else
    candidateTable = catalog;
    possibleBearings = catalog;
end

%% RESULTATTABEL FOR DRIFTSTILSTANDE

stateNumber = (1:N)';
if strcmp(loadMode,'candidate_lookup')
    stateTable = table(stateNumber,stateNames,timeShare,n_rpm,FrWork_N,FaWork_N,VWork, ...
        dynamicLoadFactor,ratioFaVFr, ...
        'VariableNames',{'StateNo','StateName','TimeShare','n_rpm','Fr_N','Fa_N','V', ...
        'DynamicLoadFactor','Fa_over_VFr'});
else
    stateTable = table(stateNumber,stateNames,timeShare,n_rpm,FrWork_N,FaWork_N,VWork, ...
        dynamicLoadFactor,Pcommon_N,P0_N,loadRuleCommon, ...
        'VariableNames',{'StateNo','StateName','TimeShare','n_rpm','Fr_N','Fa_N','V', ...
        'DynamicLoadFactor','P_N','P0_N','LoadRule'});
end

%% TYDELIG UDSKRIFT

fprintf('\n============================================================\n')
fprintf('L2 - VALG ELLER DIMENSIONERING AF LEJE\n')
fprintf('============================================================\n')
fprintf('Lejetype:                 %s\n',bearingTypeText)
fprintf('Eksponent p:              %.6g\n',p)
fprintf('Kraevet L10h:             %.6f h\n',requiredLife_h)
fprintf('Aekvivalent n:            %.6f rpm\n',n_equiv_rpm)
fprintf('Kraevet L10:              %.6f mio. omdr.\n',requiredL10_Mrev)
fprintf('Belastningsmetode:        %s\n',loadMode)

if ~strcmp(loadMode,'candidate_lookup')
    fprintf('Aekvivalent P:            %.6f N\n',P_equiv_N)
    fprintf('Noedvendigt C:            %.6f N\n',C_required_N)
else
    fprintf(['Noedvendigt C er kandidat-afhaengigt, fordi P afhænger af ' ...
        'kandidatens C0 og f0.\n'])
end

if checkStatic
    fprintf('Maksimal statisk P0:      %.6f N\n',P0_max_N)
    fprintf('Kraevet statisk s0:       %.6f\n',s0_required)
    fprintf('Noedvendigt C0:           %.6f N\n',C0_required_N)
else
    fprintf('Statisk kontrol:          fravalgt\n')
end

if ~isnan(requiredBore_mm)
    fprintf('Kraevet huldiameter:      %.6f +/- %.6f mm\n', ...
        requiredBore_mm,boreTolerance_mm)
end

fprintf('\nDRIFTSTILSTANDE\n')
disp(stateTable)

fprintf('\nKATALOGKANDIDATER\n')
if isempty(candidateTable)
    fprintf('Den lokale katalogtabel er tom. C-kravet er stadig beregnet.\n')
else
    disp(candidateTable)
end

fprintf('\nMULIGE LEJER\n')
if isempty(possibleBearings)
    fprintf('Ingen lejer i den lokale tabel opfylder alle aktive krav.\n')
else
    disp(possibleBearings)
    fprintf('Foerste egnede leje i den sorterede tabel: %s\n', ...
        getFirstText(possibleBearings.Designation))
end
fprintf('============================================================\n')

%% RESULTATER SOM STRUCT

resultat = struct;
resultat.lejetype = bearingTypeText;
resultat.p = p;
resultat.requiredLife_h = requiredLife_h;
resultat.requiredL10_Mrev = requiredL10_Mrev;
resultat.n_equiv_rpm = n_equiv_rpm;
resultat.loadMode = loadMode;
resultat.P_equiv_N = P_equiv_N;
resultat.C_required_N = C_required_N;
resultat.C_required_by_candidate_N = C_required_by_candidate_N;
resultat.C0_required_N = C0_required_N;
resultat.P0_max_N = P0_max_N;
resultat.stateTable = stateTable;
resultat.candidateTable = candidateTable;
resultat.possibleBearings = possibleBearings;
resultat.P_by_candidate_N = P_by_candidate_N;
resultat.e_by_candidate = e_by_candidate;
resultat.Y_by_candidate = Y_by_candidate;
resultat.lookupParameter_by_candidate = lookupParameter_by_candidate;

if saveResult
    save('L2_resultat.mat','resultat')
end

%% SELVTEST

if runSelfTests
    runL2SelfTests()
    fprintf('Selvtest: 3/3 beregningstests bestaaet.\n')
end

%% LOKALE HJAELPEFUNKTIONER

function Creq = requiredDynamicRating(P_N,n_rpm,timeShare,Lreq_h,p)
% Noedvendigt dynamisk baeretal for én eller flere driftstilstande.
    P_N = P_N(:);
    n_rpm = n_rpm(:);
    timeShare = timeShare(:);
    damageLoadTerm = sum(timeShare.*n_rpm.*P_N.^p);
    Creq = (60*Lreq_h/1e6*damageLoadTerm)^(1/p);
end

function Peq = equivalentDynamicLoad(P_N,n_rpm,timeShare,p)
% Omdrejningsvaegtet aekvivalent dynamisk belastning.
    P_N = P_N(:);
    n_rpm = n_rpm(:);
    timeShare = timeShare(:);
    nEq = sum(timeShare.*n_rpm);
    if nEq > 0
        Peq = (sum(timeShare.*n_rpm.*P_N.^p)/nEq)^(1/p);
    else
        Peq = 0;
    end
end

function Lh = bearingLifeHours(C_N,P_N,n_rpm,timeShare,p)
% Samlet L10h for en driftscyklus ved lineær skadesummering.
    P_N = P_N(:);
    n_rpm = n_rpm(:);
    timeShare = timeShare(:);
    damageRate = sum(timeShare.*60.*n_rpm/1e6.*(P_N./C_N).^p);
    if damageRate > 0
        Lh = 1/damageRate;
    else
        Lh = Inf;
    end
end

function validateLoads(Fr_N,Fa_N,V)
    assert(all(isfinite(Fr_N) & Fr_N >= 0), ...
        'Alle Fr-vaerdier skal vaere ikke-negative.')
    assert(all(isfinite(Fa_N) & Fa_N >= 0), ...
        'Alle Fa-vaerdier skal vaere ikke-negative.')
    assert(all(isfinite(V) & V > 0), ...
        'Alle V-vaerdier skal vaere positive.')
end

function ratio = forceRatio(Fa_N,V,Fr_N)
    ratio = nan(size(Fr_N));
    hasRadial = Fr_N > 0;
    ratio(hasRadial) = Fa_N(hasRadial)./(V(hasRadial).*Fr_N(hasRadial));
    ratio(~hasRadial & Fa_N > 0) = Inf;
    ratio(Fr_N == 0 & Fa_N == 0) = 0;
end

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
% Giver en cellekolonne med ét navn pr. driftstilstand.
    if isempty(inputNames)
        names = arrayfun(@(k) sprintf('Tilstand %d',k), ...
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
        error('stateNames skal vaere tekst, string-array eller cell-array.')
    end

    if numel(names) == 1 && N > 1
        baseName = char(names{1});
        names = arrayfun(@(k) sprintf('%s %d',baseName,k), ...
            (1:N)','UniformOutput',false);
    elseif numel(names) ~= N
        error('stateNames skal have 1 eller %d elementer.',N)
    end

    names = cellfun(@char,names,'UniformOutput',false);
end

function typeKey = normalizeTypeColumn(typeColumn)
% Normaliserer katalogets typekolonne til 'ball' eller 'roller'.
    if isstring(typeColumn)
        raw = cellstr(typeColumn(:));
    elseif ischar(typeColumn)
        raw = cellstr(typeColumn);
    elseif iscell(typeColumn)
        raw = typeColumn(:);
    else
        error('Katalogets Type-kolonne skal indeholde tekst.')
    end

    typeKey = cell(size(raw));
    for k = 1:numel(raw)
        value = lower(strtrim(char(raw{k})));
        switch value
            case {'ball','kugle','kugleleje'}
                typeKey{k} = 'ball';
            case {'roller','rulle','rulleleje'}
                typeKey{k} = 'roller';
            otherwise
                typeKey{k} = value;
        end
    end
end

function reasons = appendFailure(reasons,mask,newReason)
% Tilfoejer en kort fejltekst uden at overskrive tidligere fejl.
    indices = find(mask);
    for k = 1:numel(indices)
        i = indices(k);
        if isempty(reasons{i})
            reasons{i} = newReason;
        else
            reasons{i} = [reasons{i} ', ' newReason]; %#ok<AGROW>
        end
    end
end

function textValue = getFirstText(column)
% Henter foerste tekstvaerdi fra cell-, string- eller char-kolonne.
    if iscell(column)
        textValue = char(column{1});
    elseif isstring(column)
        textValue = char(column(1));
    elseif ischar(column)
        textValue = strtrim(column(1,:));
    else
        textValue = char(string(column(1)));
    end
end

function runL2SelfTests()
% Test 1: kursusopgaven SKF 627, radiallast, beregnet baglaens.
    C1 = requiredDynamicRating(500,2900,1,1887.98275862069,3);
    assert(abs(C1-3450) < 1e-6, ...
        'Selvtest 1 fejlede: SKF 627 radialtilfaelde.')

% Test 2: kursusopgaven SKF 627, ren aksiallast, beregnet baglaens.
    P2 = 545.27563232;
    L2 = 1455.65939191;
    C2 = requiredDynamicRating(P2,2900,1,L2,3);
    assert(abs(C2-3450) < 1e-4, ...
        'Selvtest 2 fejlede: SKF 627 aksialtilfaelde.')

% Test 3: varierende last. Beregn levetid for et kendt C og find C igen.
    Cknown = 10000;
    P = [2000;4000];
    n = [1000;500];
    q = [0.75;0.25];
    Lknown = bearingLifeHours(Cknown,P,n,q,3);
    C3 = requiredDynamicRating(P,n,q,Lknown,3);
    assert(abs(C3-Cknown) < 1e-8, ...
        'Selvtest 3 fejlede: varierende last.')
end
