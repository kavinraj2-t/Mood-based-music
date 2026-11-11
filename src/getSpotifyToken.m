function token = getSpotifyToken(clientId, clientSecret, options)
    % GETSPOTIFYTOKEN Acquires an OAuth bearer token using Client Credentials flow.
    %
    %   Syntax:
    %       token = getSpotifyToken(clientId, clientSecret)
    %       token = getSpotifyToken(clientId, clientSecret, ForceRefresh=true)
    %
    %   Example:
    %       token = getSpotifyToken("my_id", "my_secret");
    %
    %   Inputs:
    %       clientId     - Spotify Client ID string.
    %       clientSecret - Spotify Client Secret string.
    %       options      - Name-Value pairs:
    %                      * ForceRefresh (logical) - bypasses internal token cache.
    %
    %   Outputs:
    %       token        - String scalar bearer token for Spotify API requests.

    arguments
        clientId (1,1) string {mustBeNonempty}
        clientSecret (1,1) string {mustBeNonempty}
        options.ForceRefresh (1,1) logical = false
    end

    persistent cachedToken;
    persistent tokenExpiryTime;

    % Use cached token if valid (with 60-second safety cushion)
    if ~options.ForceRefresh && ~isempty(cachedToken) && ~isempty(tokenExpiryTime)
        if datetime('now') < (tokenExpiryTime - seconds(60))
            token = cachedToken;
            return;
        end
    end

    tokenUrl = "https://accounts.spotify.com/api/token";
    webOpts = weboptions( ...
        'MediaType', 'application/x-www-form-urlencoded', ...
        'Timeout', 10, ...
        'CharacterEncoding', 'UTF-8' ...
    );

    payload = struct( ...
        'grant_type', 'client_credentials', ...
        'client_id', clientId, ...
        'client_secret', clientSecret ...
    );

    try
        response = webwrite(tokenUrl, payload, webOpts);
        if ~isfield(response, 'access_token')
            error("getSpotifyToken:NoAccessToken", "Spotify response did not contain 'access_token'.");
        end
        token = string(response.access_token);
        expiresInSeconds = double(response.expires_in);

        % Cache credentials
        cachedToken = token;
        tokenExpiryTime = datetime('now') + seconds(expiresInSeconds);
    catch ME
        error("getSpotifyToken:AuthFailure", ...
            "Spotify authorization failed. Verify credentials and network connection. Details: %s", ME.message);
    end
end
