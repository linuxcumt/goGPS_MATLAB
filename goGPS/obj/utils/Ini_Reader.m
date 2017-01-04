% Ini_Reader(file_name, verbosity)
%
% =========================================================================
%   OBJECT Ini_Reader
% =========================================================================
%
% DESCRIPTION:
%   Object to read an ini file
%
% INI EXAMPLE:
%   [Section 1]
%       array = [1 2 3]
%       string = "I'm a string"
%       stringCellArray = ["I" "am" "a string cell" "array"]
%   ; I'm a comment
%   # I'm also a comment
%   [Section 2]
%       number = 10
%   [Section n]     # comment
%       double = 10.4
%
% REQUIRES when color_mode is set to true:
%   cprintf:    http://www.mathworks.com/matlabcentral/fileexchange/24093-cprintf-display-formatted-colored-text-in-the-command-window
%
%----------------------------------------------------------------------------------------------
%                           goGPS v0.5.9
%
% Copyright (C) 2009-2014 Mirko Reguzzoni, Eugenio Realini
% Written by:       Gatti Andrea
% Contributors:     Gatti Andrea, ...
%----------------------------------------------------------------------------------------------
%
%    Code contributed by Andrea Gatti
%
%    This program is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    This program is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with this program.  If not, see <http://www.gnu.org/licenses/>.
%---------------------------------------------------------------------------------------------

classdef Ini_Reader < handle
      
    properties (GetAccess = 'public', SetAccess = 'protected')
        c_comment  = [';', '#'];       % Character Identifying the start of a comments
        file_name = 'config.ini';      % Name (and full path) of the ini
        fid = 0;                       % Handle of the ini file
        raw_data = {};                 % Cell array containing the file, each cell is a line
        rw = 'r';                      % File access mode (r/w)
        read_status = false;           % Flag of reading status
        verbosity = 1;                 % Verbosity level 
        color_mode = true;             % Flag for coloured output messages (if true requires cprintf)
    
        % Structure containing the data: section -> name / ( key -> (name / data )
        section = {};
        %section{1}.name = 'Section Name';
        %section{1}.key = {};
        %section{1}.key{1}.name = 'Key name';
        %section{1}.key{1}.data = 100;
    end
    
    % =========================================================================
    %    PUBLIC METHODS
    % =========================================================================
    methods
        
        % Creator
        function obj = Ini_Reader(file_name, verbosity)
        % IniReader(file_name, verbosity) creator
            if (nargin == 0)
                file_name = '';
            end
            if isempty(file_name)
                file_name = '';
            end
            obj.setFileName(file_name);
            if (nargin == 2)
                obj.setVerbosityLev(verbosity);
            end            
        end
        
        % Distructor
        function delete(obj)
            
        end
        
        % Cleaner
        function clearAll(obj)
            % Reset the object
            obj.fid = 0;
            obj.rw = 'r';
            obj.file_name = 'config.ini';
            obj.raw_data = {};
            obj.verbosity = 1;
            obj.color_mode = 1;
            obj.section = {};
        end
    end
    
    % =========================================================================
    %  FILE
    % =========================================================================
    methods    
        
        % Set file name ---------------------------------------------------
        function setFileName(obj, file_name)
            % Set the complete path of the ini file
            obj.file_name = file_name;
        end
        
        function file_name = getFileName(obj)
            % Get the complete path of the ini file
            file_name = obj.file_name;
        end
    end
    
    % =========================================================================
    %  INI SYNTAX
    % =========================================================================
    methods    
        % Set Comment Character -------------------------------------------
        function setCommentChar(obj, character)
            % define the characters that define comment lines
            obj.c_comment = character;
        end
        
        function characters = getCommentChar(obj)
            % Get the characters that define comment lines
            characters = obj.c_comment;
        end

    end
    
    % =========================================================================
    %  R/W MODES OF THE FILE
    % =========================================================================
    methods    
                
        % Set RW mode -----------------------------------------------------
        function setRW(obj,rwMode)
            % Set mode for open the ini file
            if ( ~obj.readMode() && ~writeMode())
                obj.rw = 'r';
            else
                obj.rw = rwMode;
            end
        end
        
        function rwMode = getRW(obj)
            % Get the current mode of the file
            rwMode = obj.rw;
        end
        
        function bool = readMode(obj)
            % Is it in read mode?
            if ((obj.rw(1)=='r'))
                bool = true;
            else
                bool = false;
            end
        end
        
        function bool = writeMode(obj)
            % Is it in write mode?
            if ((obj.rw(1)=='w'))
                bool = true;
            else
                bool = false;
            end
        end
        
        % Get read status mode --------------------------------------------        
        function bool = getReadStatus(obj)
            % Return if the file has been already parsed
            bool = obj.read_status;
        end
        
        % Read File -------------------------------------------------------
        function errStatus = readFile(obj)
            % Force reading of the File
            errStatus = false;            
            % If the object already contains data - clean it
            if (obj.getReadStatus())
                obj.raw_data = {};
            end
            if ~exist(obj.getFileName(),'file')
                obj.printError('File not found');
                errStatus = true;
            else
                obj.fid = fopen(obj.getFileName(), obj.getRW());
                
                if (obj.fid ~= -1)   % If reading is ok
                    obj.raw_data = textscan(obj.fid, '%s', 'delimiter', '\n', 'endOfLine', '\r\n');
                    
                    fclose(obj.fid);
                    
                    obj.read_status = true;
                    obj.raw_data = obj.raw_data{1};
                    
                    if (obj.getVerbosityLev)
                        obj.opStatus(1, obj.color_mode);
                        if obj.color_mode
                            cprintf('The INI file has been read correctly.\n');
                        else
                            fprintf('The INI file has been read correctly.\n');
                        end
                    end
                    
                    obj.cleanRaw();      % Strip comments and spaces
                    obj.parseData();     % Parse file
                    obj.raw_data = {};   % clean RAW temp data
                else
                    obj.printError(ferror(obj.fid));
                    obj.setReadStatus(false);
                    obj.raw_data = {};
                end
            end
        end
        
        % Update File (when needed) ---------------------------------------
        function reloaded = update(obj, file_name, force)
            % Update the object when needed:
            %  - file_name changed 
            %  - force flag == 1
            %  - INI not yet read
            if nargin == 2
                force = 0;
            end
            reloaded = 0;
            if (~strcmp(file_name,obj.getFileName) || (force == 1) || ~obj.getReadStatus())
                obj.setFileName(file_name);
                obj.readFile();
                reloaded = 1;
            end            
        end
        
    end
    
    % =========================================================================
    %  MANAGING LOGGING
    % =========================================================================
    methods    
    
        % Set read status mode --------------------------------------------
        function setColorMode(obj, bool)
            % Set useage of colors in text output
            obj.color_mode = bool;
        end
        
        function bool = getColorMode(obj)
            % Get useage of colors in text output
            bool = obj.color_mode;
        end
        
        % Set verbosity level ---------------------------------------------
        function setVerbosityLev(obj, verbosity)
            % Set level of verbosity
            obj.verbosity = verbosity;
        end
        
        function verbosity = getVerbosityLev(obj)
            % Get level of verbosity
            verbosity = obj.verbosity;
        end
    end
    
    % =========================================================================
    %  GETTER OF THE PARAMETERS
    % =========================================================================
    methods
        
        % Get the list of sections present in the file --------------------        
        function section_list = getSections(obj)
            % Get the list of available sections
            if (~obj.getReadStatus())
                %obj.printWarning('File not yet read!\n');
                obj.readFile();
            end
            
            section_list = {};
            for s=1:length(obj.section)
                section_list{s} = obj.section{s}.name;
            end
        end 
        
        % Return the presence of a section --------------------------------
        function isS = isSection(obj, section)
            % Get the presence of a section
            s = 1;
            while ((s<=length(obj.section)) && (s ~= 0))
                if (strcmp(obj.section{s}.name,section))
                    s = 0;      % Stop searching
                else
                    s = s+1;    % go on with the search of the section
                end
            end
           isS = s == 0;
        end
        
        % Return the presence of a key ------------------------------------
        function isK = isKey(obj, section, key)
            % Get the presence of a key 
            s = 1;
            k = 1;
            while ((s<=length(obj.section)) && (s ~= 0))
                if (strcmp(obj.section{s}.name,section))
                    k = 1;
                    while ((k<=length(obj.section{s}.key)) && (k ~= 0))
                        if (strcmp(obj.section{s}.key{k}.name,key))
                            k = 0;
                        else
                            k = k + 1;
                        end
                    end
                    s = 0;
                else
                    s = s + 1;    % go on with the search of the section
                end
            end
            isK = k == 0;
        end
                
        % Get the list of keys present in the file ------------------------
        function keyList = getKeys(obj, section)
            % Get the list of the keys available
            if (nargin == 1)
                section = 0;
            end
            
            if (~obj.getReadStatus())                
                %obj.printWarning('File not yet read!\n');
                obj.readFile();
            end
            
            keyList = {};
            l = 1;
            if (section == 0)
                for s = 1:length(obj.section)
                    for p = 1:length(obj.section{s}.key)
                        keyList{l} = obj.section{s}.key{p}.name;
                        l = l+1;
                    end
                end
            else
                s = 1;
                while ((s<=length(obj.section)) && (s ~= 0))
                    if (strcmp(obj.section{s}.name,section))
                        for p = 1:length(obj.section{s}.key)
                            keyList{l} = obj.section{s}.key{p}.name;
                            l = l+1;
                        end
                        s = 0;      % Stop searching
                    else
                        s = s+1;    % go on with the search of the section
                    end
                end
            end
        end
        
        % Get data --------------------------------------------------------        
        function data = getData(obj, section, key, print_errors)
            % extract the value of a key
            if nargin == 3
                print_errors = 0;
            end
            
            % Get the value of a specified key
            if (~obj.getReadStatus() && isempty(obj.section))
               %obj.printWarning('File not yet read!\n');
               obj.readFile();
            end
            
            data = [];
            if (nargin == 2)
                key = section;
                % Search the key among all the sections
                s = 1;
                while ((s<=length(obj.section)) && (s > 0))
                    p = 1;
                    while ((p <= length(obj.section{s}.key)) && (p ~= 0))
                        if (strcmp(obj.section{s}.key{p}.name,key))
                            data = obj.section{s}.key{p}.data;
                            p = 0;      % Stop searching key
                        else
                            p = p+1;    % go on with the search of the key
                        end
                    end
                    if (p == 0)
                        s = 0;     % Stop searching section
                    else
                        s = s+1;   % go on with the search of the section
                    end
                end
            else                
                % Search the key of a specific section
                s = 1;
                while ((s<=length(obj.section)) && (s > 0))
                    if (strcmp(obj.section{s}.name,section))
                        p = 1;
                        while ((p <= length(obj.section{s}.key)) && (p ~= 0))
                            if (strcmp(obj.section{s}.key{p}.name,key))
                                data = obj.section{s}.key{p}.data;
                                p = 0; % Stop searching key
                            else
                                p = p+1;    % go on with the search of the key
                            end
                        end
                        s = 0;      % Stop searching section
                    else
                        s = s+1;    % go on with the search of the section
                    end
                end
            end
            
            if (isempty(data) && print_errors)
                obj.printError(['Key "' key '" not found!\n']);
                data = [];
            end
        end
    end        
    
    % =========================================================================
    %  SEARCH FUNCTIONS
    % =========================================================================
    methods
        % Search a section in the object IniReader ------------------------
        function isPresent = containsSection(obj, section)
            % Search a section in the object IniReader
            s = 1;
            while ((s<=length(obj.section)) && (s ~= 0))
                if (strcmp(obj.section{s}.name,section))
                    s = 0;
                else
                    s = s + 1;    % go on with the search of the section
                end
            end
            if (s == 0)
                isPresent = true;
            else
                isPresent = false;
            end
        end
        
        % Search a key in the object IniReader ----------------------------
        function isPresent = containsKey(obj, section, key)
            % Search a key in the object IniReader
            s = 1;
            while ((s<=length(obj.section)) && (s ~= 0))
                if (strcmp(obj.section{s}.name,section))
                    while ((k<=length(obj.section{s}.key)) && (k ~= 0))
                        if (strcmp(obj.section{s}.key{k}.name,key))
                            k = 0;
                        else
                            k = k + 1;
                        end
                    end
                    s = 0;
                else
                    s = s + 1;    % go on with the search of the section
                end
            end
            if (k == 0)
                isPresent = true;
            else
                isPresent = false;
            end
        end                
    end
    
    % =========================================================================
    %  VISUALIZATION FUNCTIONS
    % =========================================================================
    methods
        % List Sections ---------------------------------------------------
        function listSections(obj, color_mode)
            % List the list of available sections
            if (nargin == 1)
                color_mode = obj.getColorMode();
            end
            
            if (~obj.getReadStatus())
                %obj.printWarning('File not yet read!\n');

                obj.readFile();
            end
            
            fprintf('        List of sections:\n')
            for s=1:length(obj.section)
                obj.printSection(obj.section{s}.name, color_mode);
            end
        end
        
        % List Key --------------------------------------------------------
        function listKeys(obj, section, color_mode)
            % List the list of the keys available
            if (nargin == 1)
                section = 0;
                color_mode = obj.getColorMode();
            end
            if (nargin == 2)
                if (ischar(section))
                    color_mode = obj.color_mode;
                else
                    color_mode = section;
                    section = 0;
                end                
            end
            
            if (~obj.getReadStatus() && isempty(obj.section))
                %obj.printWarning('File not yet read!\n');
                obj.readFile();
            end
            
            if (section == 0)
                fprintf('        List of all the keys:\n')
                for s = 1:length(obj.section)
                    obj.printSection(obj.section{s}.name, color_mode);
                    for p = 1:length(obj.section{s}.key)
                        obj.printData(obj.section{s}.key{p}.name, obj.section{s}.key{p}.data, color_mode)
                    end
                end
            else
                fprintf('        List of all the keys in section "%s":\n', section)
                s = 1;
                while ((s<=length(obj.section)) && (s ~= 0))
                    if (strcmp(obj.section{s}.name,section))
                        obj.printSection(obj.section{s}.name, color_mode);
                        for p = 1:length(obj.section{s}.key)
                            obj.printData(obj.section{s}.key{p}.name, obj.section{s}.key{p}.data, color_mode)
                        end
                        s = 0;      % Stop searching
                    else
                        s = s+1;    % go on with the search of the section
                    end
                end
            end
        end

        % Show data -------------------------------------------------------
        function showData(obj, section, color_mode)
            % List the data contained in the ini
            if (nargin == 1)
                section = 0;
                color_mode = obj.color_mode;
            end
            if (nargin == 2)
                if (ischar(section))
                    color_mode = obj.color_mode;
                else
                    color_mode = section;
                    section = 0;
                end                
            end            
            
            if (~obj.getReadStatus())
                %obj.printWarning('File not yet read')
                obj.readFile();
            end
            
            if (section == 0)
                fprintf('        List of all the key values:\n')
                for s = 1:length(obj.section)
                    obj.printSection(obj.section{s}.name, color_mode);
                    for p = 1:length(obj.section{s}.key)
                        obj.printData(obj.section{s}.key{p}.name, obj.section{s}.key{p}.data, color_mode)
                    end
                end
            else
                fprintf('        List of all the key values in section "%s":\n', section)
                s = 1;
                while ((s <= length(obj.section)) && (s ~= 0))
                    if (strcmp(obj.section{s}.name,section))
                        obj.printSection(obj.section{s}.name, color_mode);
                        for p = 1:length(obj.section{s}.key)
                            obj.printData(obj.section{s}.key{p}.name, obj.section{s}.key{p}.data, color_mode)                           
                        end
                        s = 0;      % Stop searching
                    else
                        s = s+1;    % go on with the search of the section
                    end
                end
            end
        end        
    end
    
    % =========================================================================
    %    PRIVATE METHODS
    % =========================================================================
    
    methods (Access = 'private')
        
        % Strip empty/comment lines
        function cleanRaw(obj)
            % Strip empty lines
            obj.raw_data((cellfun(@length, obj.raw_data)==0)) = [];
            % Strip commented lines
            r = 1;
            while (r <= length(obj.raw_data))
                if ismember(obj.raw_data{r}(1), obj.c_comment);
                    obj.raw_data(r) = [];
                else
                    r = r + 1;
                end
            end
            
            for r=1:length(obj.raw_data)
                % Strip comments
                
                start = regexp(obj.raw_data{r}, ['([' obj.c_comment ']).*'], 'start');
                if (~isempty(start))
                    obj.raw_data{r}(start:end) = [];
                end
                
                start = regexp(obj.raw_data{r}, ' *$', 'start');
                if (~isempty(start))
                    obj.raw_data{r}(start:end) = [];
                end
            end
        end
        
        % Parse the file (cleaned)
        function parseData(obj)
            s = 0;
            obj.section = {};
            for r=1:length(obj.raw_data)
                sectionName = regexp(obj.raw_data{r}, '(?<=^\[).*(?=\])', 'match');
                if (~isempty(sectionName))
                    % we have a new SECTION!
                    s = s+1;
                    p = 0;
                    obj.section{s}.name = sectionName{1};
                    obj.section{s}.key = [];
                else
                    % maybe this line contains a key, let's check
                    parName = regexp(obj.raw_data{r}, '^(.*(?=\s\=))', 'match');
                    if (isempty(parName))
                        parName = regexp(obj.raw_data{r}, '^(.*(?=\=))', 'match');
                    end
                    if (~isempty(parName))
                        % we have a PARAMETER!
                        p = p+1;
                        obj.section{s}.key{p}.name = parName{1};
                        
                        % Get the DATA!
                        strData = regexp(obj.raw_data{r}, '(?<=\=).*', 'match');
                        if (isempty(strData))
                            obj.section{s}.key{p}.data = [];
                        else
                            tmpData = str2num(strData{1});
                            if (~isempty(tmpData))   % It's a number!
                                obj.section{s}.key{p}.data = tmpData;
                            else
                                % It's a string!
                                % If it is a string properly formatted "string data"
                                tmpData = regexp(strData{1}, '(?<=\")[^"]*(?=\")', 'match');
                                if (~isempty(tmpData))
                                    if (size(tmpData,2) == 1)
                                        obj.section{s}.key{p}.data = tmpData{1};
                                    else                                        
                                        % Strip empty cells
                                        tmpData((cellfun(@length, tmpData)==0)) = [];
                                        % Strip space only cells
                                        for c=size(tmpData,2):-1:1
                                            if isempty(regexp(tmpData{c}, '[^ ]*', 'match'))
                                                tmpData(c) = [];
                                            end
                                        end
                                        obj.section{s}.key{p}.data = tmpData;
                                    end
                                else
                                    % If it is not a string but apparently is
                                    % not a number
                                    obj.section{s}.key{p}.data = strData{1};
                                end
                            end
                        end
                    end
                    
                end
                
            end
        end 
        
        % Set read status
        function setReadStatus(obj, bool)
            obj.read_status = bool;
        end

        
% =========================================================================
%    DISPLAY UTILITIES
% =========================================================================

        % Display Warning        
        function printWarning(obj, text, color_mode)
            if (nargin == 2)
                color_mode = obj.color_mode;
            end
            if (obj.getVerbosityLev > 0)
                obj.opStatus(0, color_mode);
                if (color_mode)
                    cprintf('err', 'warning: ');
                    cprintf('text', [text '\n']);
                else
                    fprintf('warning: %s\n', text);
                end
            end
        end
        
        % Display Error        
        function printError(obj, text, color_mode)
            if (nargin == 2)
                color_mode = obj.color_mode;
            end
            if (obj.getVerbosityLev > 0)
                obj.opStatus(0, color_mode);
                if (color_mode)
                    cprintf('err', 'Error: ');
                    cprintf('text', [text '\n']);
                else
                    fprintf('Error: %s\n', text);
                end
            end
        end
        
        % Display a Section
        function printSection(obj, section, color_mode)
            if (nargin == 2)
                color_mode = obj.color_mode;
            end
            if (color_mode)
                cprintf('blue','         - ');
                cprintf('text', '"%s"\n', section);
            else
                fprintf('         - "%s"\n', section);
            end
        end
        
        % Display a Key
        function printKey(obj, key, color_mode)
            if (nargin == 2)
                color_mode = obj.color_mode;
            end
            if (color_mode)
                cprintf('blue','             |- ');
                cprintf('text', '"%s"\n', key);                
            else
                fprintf('             |- "%s"\n', key);
            end
        end
        
        % Display a Key
        function printData(obj, key, data, color_mode)
            if (nargin == 3)
                color_mode = obj.color_mode;
            end
            if (color_mode)
                cprintf('blue','             |- ');
                tmpData = data;
                if (iscell(tmpData))    % The only dataset that can be a cell array is an array of strings
                    cprintf('text','"%s" = [', key);
                    for (l = 1:size(tmpData,2))
                        cprintf('text', ' "%s"', tmpData{l});
                    end
                    cprintf('text', ' ]\n');
                else
                    % if it is not an array of string...
                    if (ischar(tmpData))
                        cprintf('text','"%s" = "%s"\n',key, num2str(tmpData));
                    else
                        cprintf('text','"%s" = %s\n',key, num2str(tmpData));
                    end
                end
            else
                tmpData = data;
                if (iscell(tmpData))    % The only dataset that can be a cell array is an array of strings
                    fprintf('             |- "%s" = [', key);
                    for l = 1:size(tmpData,2)
                        fprintf(' "%s"', tmpData{l});
                    end
                    fprintf(' ]\n');
                else
                    % if it iks not an array of string...
                    if (ischar(tmpData))
                        fprintf('             |- "%s" = "%s"\n',key, num2str(tmpData));
                    else    
                        fprintf('             |- "%s" = %s\n',key, num2str(tmpData));
                    end
                end
            end
        end
    end
    
% =========================================================================
%    DISPLAY UTILITIES
% =========================================================================

    methods(Static, Access = 'public')
        
        % Display a flag of operation status
        function opStatus(statusOk, color_mode)
            if (nargin == 1)
                color_mode = true;
            end
            if color_mode
                cprintf('blue',' [ ');
                if (statusOk)
                    cprintf('green','ok');
                else
                    cprintf('red','!!');
                end
                cprintf('blue',' ] ');
            else
                fprintf(' [ ');
                if (statusOk)
                    fprintf('ok');
                else
                    fprintf('!!');
                end
                fprintf(' ] ');
            end
        end        
    end
end