function finalUncert = calcFinalTempUncert(nr,nc,mask,elev,baseInterpUncert,baseInterpElev,slopeUncert,filterSize,filterSpread,covWindow)
%
%% calcFinalTempUncert computes the final uncertainty for temperature variables
%
% Arguments:
%
%  Inputs:
%
%   nr, integer,   number of rows in grid
%   nc, integer,   number of columns in grid
%   mask, integer, mask of valid grid points
%   baseInterpUncert, float, intiial baseInterp uncertainty estimate across grid
%   slopeUncert, float, initial estimate of slope uncertainty across grid
%   filterSize, integer, size of low-pass filter in grid points
%   filterSpread, float, variance of low-pass filter
%   covWindow, float, size (grid points) of covariance window
%
%  Outputs:
%
%   finalUncert, structure, structure containing total and relative
%                           uncertainty for met var
%
% Author: Andrew Newman, NCAR/RAL
% Email : anewman@ucar.edu
% Postal address:
%     P.O. Box 3000
%     Boulder,CO 80307
% 
% Copyright (C) 2019 Andrew Newman
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <https://www.gnu.org/licenses/>.
%

    %define a mesh of indicies for scattered interpolation of valid points
    %back to a grid
    y = 1:nr;
    x = 1:nc;
    [y2d,x2d] = meshgrid(x,y);

    %find valid points for baseInterp uncertainty
    [i,j] = find(~isnan(baseInterpUncert));
    %scattered interpolation using griddata
    interpBaseInterp = griddata(i,j,baseInterpUncert(~isnan(baseInterpUncert)),x2d,y2d,'linear');
    %fill missing values with nearest neighbor
    interpBaseInterp = fillNaN(interpBaseInterp,x2d,y2d);
    
    %find valid points for slope uncertaintty
    [i,j] = find(slopeUncert >= 0);
    %scattered interpolation using griddata
    interpSlope = griddata(i,j,slopeUncert(slopeUncert>=0),x2d,y2d,'linear');
    interpSlope = interpSlope.*abs(baseInterpElev-elev);
    %fill missing values with nearest neighbor
    interpSlope = fillNaN(interpSlope,x2d,y2d);
    
    %gaussian low-pass filter
    gFilter = fspecial('gaussian',[filterSize filterSize],filterSpread);
    
    %filter uncertainty estimates
    finalBaseInterpUncert = imfilter(interpBaseInterp,gFilter);
    finalSlopeUncert = imfilter(interpSlope,gFilter);
    
    %replace nonvalid mask points with NaN
    finalBaseInterpUncert(mask<0) = NaN;
    finalSlopeUncert(mask<0) = NaN;
%     
%     figure(33);
%     imagesc(interpSlope');
%     set(gca,'ydir','normal');
%     colorbar;
%     
%     figure(34);
%     imagesc(finalSlopeUncert');
%     set(gca,'ydir','normal');
%     colorbar;
%     
    %estimate the total and relative uncertainty in physical units 

    %define a local covariance vector
    localCov = zeros(size(finalBaseInterpUncert))*NaN;

    %step through each grid point and estimate the local covariance between
    %the two uncertainty components using covWindow to define the size of the local covariance estimate
    %covariance influences the total combined estimate
    for i = 1:nr
        for j = 1:nc
            %define indicies aware of array bounds
            iInds = [max([1 i-covWindow]),min([nr i+covWindow])];
            jInds = [max([1 j-covWindow]),min([nc j+covWindow])];

            %compute local covariance using selection of valid points
            %get windowed area
            subBaseInterp = finalBaseInterpUncert(iInds(1):iInds(2),jInds(1):jInds(2));
            subSlope = finalSlopeUncert(iInds(1):iInds(2),jInds(1):jInds(2));
            %compute covariance for only valid points in window
            c = cov(subBaseInterp(~isnan(subBaseInterp)),subSlope(~isnan(subSlope)),0);
            %pull relevant value from covariance matrix
            localCov(i,j) = c(1,length(c(1,:)));
        end
    end

    %compute the total estimates 
    finalUncert.totalUncert = finalSlopeUncert+finalBaseInterpUncert+2*sqrt(abs(localCov));
    finalUncert.relativeUncert = zeros(size(finalUncert.totalUncert))*NaN;

    %set novalid gridpoints to missing
    finalBaseInterpUncert(mask<0) = -999;
    finalSlopeUncert(mask<0) = -999;
    finalUncert.totalUncert(mask<0) = -999;
    finalUncert.relativeUncert(mask<0) = -999;    

    %define components in output structure
    finalUncert.finalBaseInterpUncert = finalBaseInterpUncert;
    finalUncert.finalSlopeUncert = finalSlopeUncert;


end
