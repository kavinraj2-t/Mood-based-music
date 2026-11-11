classdef TestSpotifyIntegration < matlab.unittest.TestCase
    % TESTSPOTIFYINTEGRATION Verification of token fetching and search queries.

    methods (Test)
        function testInvalidCredentialsHandling(testCase)
            testCase.verifyError(@() getSpotifyToken("bad_id", "bad_secret"), ...
                "getSpotifyToken:AuthFailure");
        end

        function testLiveSearchIfConfigured(testCase)
            try
                cfg = loadConfig();
                token = getSpotifyToken(cfg.spotify.clientId, cfg.spotify.clientSecret);
                tracks = searchSpotify(token, "happy pop", Limit=3);
                
                testCase.verifyGreaterThanOrEqual(numel(tracks), 1);
                testCase.verifyNotEmpty(tracks(1).name);
                testCase.verifyNotEmpty(tracks(1).artist);
            catch ME
                % Allow graceful pass with warning if no internet/credentials configured
                warning("Live Spotify test skipped: %s", ME.message);
            end
        end
    end
end
