clear;
clc;
close all;

%% Locate the preprocessing script and helper functions

scriptDir = fileparts(mfilename('fullpath'));

addpath(scriptDir);

%% Process Subject 2 only

subjectIds = 2;

run(fullfile(scriptDir, 'EEG_Preprocessing.m'));