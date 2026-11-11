function sampleImg = generateSampleData()
    % GENERATESAMPLEDATA Creates a synthetic test image with a face outline.
    %
    %   Syntax:
    %       img = generateSampleData()
    %
    %   Example:
    %       img = generateSampleData();
    %       imshow(img);
    %
    %   Outputs:
    %       sampleImg - 480x640x3 uint8 synthetic RGB image.

    arguments
    end

    % 480x640 blank slate
    sampleImg = uint8(ones(480, 640, 3) * 220);

    % Draw head ellipse
    [X, Y] = meshgrid(1:640, 1:480);
    headMask = (((X - 320)/110).^2 + ((Y - 240)/140).^2) <= 1;
    for c = 1:3
        channel = sampleImg(:,:,c);
        channel(headMask) = 245;
        sampleImg(:,:,c) = channel;
    end

    % Draw eyes
    leftEye = (((X - 275)/15).^2 + ((Y - 210)/12).^2) <= 1;
    rightEye = (((X - 365)/15).^2 + ((Y - 210)/12).^2) <= 1;
    sampleImg(repmat(leftEye | rightEye, [1 1 3])) = 40;

    % Draw smile arc
    smileMask = (((X - 320)/60).^2 + ((Y - 280)/30).^2 <= 1) & (Y >= 280);
    sampleImg(repmat(smileMask, [1 1 3])) = 50;
end
