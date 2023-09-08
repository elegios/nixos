{ lib, python3Packages, fetchPypi }:

python3Packages.buildPythonApplication rec {
  pname = "edir";
  version = "2.21";

  format = "pyproject";
  propagatedBuildInputs = with python3Packages; [setuptools setuptools-scm platformdirs];

  src = fetchPypi {
    inherit pname version;
    sha256 = "5nqClSs2qqZ64nzvdC06hcL4ItDkBy8rqzV0CCFgmnM=";
  };

  meta = with lib; {
    description = "Program to rename and remove files and directories using your editor";
    homepage = "https://github.com/bulletmark/edir";
    license = licenses.gpl3Plus;
    maintainers = with maintainers; [ guyonvarch ];
    platforms = platforms.all;
  };
}
