#
# json: Reading and Writing JSON
#
# This file contains package meta data. For additional information on
# the meaning and correct usage of these fields, please consult the
# manual of the "Example" package as well as the comments in its
# PackageInfo.g file.
#
SetPackageInfo( rec(

PackageName := "json",
Subtitle := "Reading and Writing JSON",
Version := "2.2.2",
Date := "27/08/2024", # dd/mm/yyyy format
License := "BSD-2-Clause",

Persons := [
  rec(
    IsAuthor := true,
    IsMaintainer := true,
    FirstNames := "Christopher",
    LastName := "Jefferson",
    WWWHome := "https://heather.cafe/",
    Email := "caj21@st-andrews.ac.uk",
    PostalAddress := Concatenation(
               "St Andrews\n",
               "Scotland\n",
               "UK" ),
    Place := "St Andrews",
    Institution := "University of St Andrews",
  ),
],

PackageWWWHome := "https://gap-packages.github.io/json/",

ArchiveURL     := Concatenation("https://github.com/gap-packages/json/",
                                "releases/download/v", ~.Version,
                                "/json-", ~.Version),
README_URL     := Concatenation( ~.PackageWWWHome, "README" ),
PackageInfoURL := Concatenation( ~.PackageWWWHome, "PackageInfo.g" ),

ArchiveFormats := ".tar.gz",

##  Status information. Currently the following cases are recognized:
##    "accepted"      for successfully refereed packages
##    "submitted"     for packages submitted for the refereeing
##    "deposited"     for packages for which the GAP developers agreed
##                    to distribute them with the core GAP system
##    "dev"           for development versions of packages
##    "other"         for all other packages
##
Status := "deposited",

SourceRepository := rec(
  Type := "git",
  URL := "https://github.com/gap-packages/json"
),
IssueTrackerURL := Concatenation( ~.SourceRepository.URL, "/issues" ),

AbstractHTML   :=  "",

PackageDoc := rec(
  BookName  := "json",
  ArchiveURLSubset := ["doc"],
  HTMLStart := "doc/chap0_mj.html",
  PDFFile   := "doc/manual.pdf",
  SixFile   := "doc/manual.six",
  LongTitle := "Reading and Writing JSON",
),

Dependencies := rec(
  GAP := ">= 4.12",
  NeededOtherPackages := [ [ "GAPDoc", ">= 1.5" ] ],
  SuggestedOtherPackages := [ ],
  ExternalConditions := [ ],
),

AvailabilityTest := function()
   if IsKernelExtensionAvailable("json") = false then
     LogPackageLoadingMessage( PACKAGE_WARNING,
             [ "kernel functions for json are not available." ] );
     return false;
   else
     return true;
   fi;
end,

TestFile := "tst/testall.g",

#Keywords := [ "TODO" ],

));
