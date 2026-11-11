function tracks = searchSpotify(token, query, options)
    % SEARCHSPOTIFY Queries the Spotify API for recommended tracks matching query.
    %
    %   Syntax:
    %       tracks = searchSpotify(token, query)
    %       tracks = searchSpotify(token, query, Limit=10)
    %
    %   Example:
    %       tracks = searchSpotify(token, "happy english pop");
    %
    %   Inputs:
    %       token   - Valid Spotify Bearer access token string.
    %       query   - Search query string.
    %       options - Name-Value pairs:
    %                 * Limit (integer) - max tracks to retrieve (default: 5).
    %
    %   Outputs:
    %       tracks  - Array of structs with fields: name, artist, url, preview_url.

    arguments
        token (1,1) string {mustBeNonempty}
        query (1,1) string {mustBeNonempty}
        options.Limit (1,1) double {mustBePositive, mustBeInteger} = 5
    end

    searchBaseUrl = "https://api.spotify.com/v1/search";
    encodedQuery = urlencode(query);
    fullUrl = sprintf("%s?q=%s&type=track&limit=%d", searchBaseUrl, encodedQuery, options.Limit);

    webOpts = weboptions( ...
        'HeaderFields', {'Authorization', "Bearer " + token}, ...
        'Timeout', 10, ...
        'ContentType', 'json' ...
    );

    try
        response = webread(fullUrl, webOpts);
    catch ME
        error("searchSpotify:ApiError", "Failed to query Spotify Search API: %s", ME.message);
    end

    tracks = struct('name', {}, 'artist', {}, 'url', {}, 'preview_url', {});

    if isfield(response, 'tracks') && isfield(response.tracks, 'items')
        rawItems = response.tracks.items;
        if iscell(rawItems)
            itemList = rawItems;
        elseif isstruct(rawItems)
            itemList = num2cell(rawItems);
        else
            itemList = {};
        end

        for i = 1:numel(itemList)
            item = itemList{i};
            
            % Extract artist name safely
            if isfield(item, 'artists') && ~isempty(item.artists)
                if iscell(item.artists)
                    artistName = string(item.artists{1}.name);
                else
                    artistName = string(item.artists(1).name);
                end
            else
                artistName = "Unknown Artist";
            end

            % Extract Spotify external URL
            trackUrl = "";
            if isfield(item, 'external_urls') && isfield(item.external_urls, 'spotify')
                trackUrl = string(item.external_urls.spotify);
            end

            % Extract preview URL
            previewUrl = "";
            if isfield(item, 'preview_url') && ~isempty(item.preview_url) && ~isa(item.preview_url, 'double')
                previewUrl = string(item.preview_url);
            end

            tracks(end+1) = struct( ...
                'name', string(item.name), ...
                'artist', artistName, ...
                'url', trackUrl, ...
                'preview_url', previewUrl ...
            );
        end
    end
end
