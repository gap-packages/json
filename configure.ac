#
# json: Reading and Writing JSON
#
# This file is part of the build system of a GAP kernel extension.
# Requires GNU autoconf, GNU automake and GNU libtool.
#

dnl ##
dnl ## Setup autoconf
dnl ##
AC_PREREQ([2.68])
AC_INIT([json], m4_esyscmd([tr -d '\n' < VERSION]))
AC_CONFIG_SRCDIR([src/json.cc])
AC_CONFIG_HEADER([src/pkgconfig.h:cnf/pkgconfig.h.in])
AC_CONFIG_MACRO_DIR([m4])
AC_CONFIG_AUX_DIR([cnf])

dnl ##
dnl ## Get canonical host info
dnl ##
AC_CANONICAL_HOST

dnl ##
dnl ## Setup automake
dnl ##
AM_INIT_AUTOMAKE([1.11 -Wall foreign subdir-objects])
AM_SILENT_RULES([yes])
AM_PROG_AR

dnl ##
dnl ## Set the language
dnl ##
AC_PROG_CXX
AC_LANG([C++])


dnl ##
dnl ## Locate the GAP root dir
dnl ##
AC_FIND_GAP

dnl ##
dnl ## Set flags so libtool will use them
dnl ##
CFLAGS="$CFLAGS $GAP_CFLAGS"
CPPFLAGS="$CPPFLAGS $GAP_CPPFLAGS"
CXXFLAGS="$CXXFLAGS $GAP_CFLAGS"
LDFLAGS="$LDFLAGS $GAP_LDFLAGS"

dnl ##
dnl ## Detect Windows resp. Cygwin
dnl ##
case $host_os in
  *cygwin* ) CYGWIN=yes;;
         * ) CYGWIN=no;;
esac
AM_CONDITIONAL([SYS_IS_CYGWIN], [test "$CYGWIN" = "yes"])
if test "$CYGWIN" = "yes"; then
  AC_DEFINE(SYS_IS_CYGWIN32, 1, are we on CYGWIN?)
else
  AC_DEFINE(SYS_IS_CYGWIN32, 0, are we on CYGWIN?)
fi



dnl ##
dnl ## Setup libtool (for building the GAP kernel extension)
dnl ##
LT_PREREQ([2.4.2])
LT_INIT([disable-static dlopen win32-dll])

dnl ##
dnl ## Output everything
dnl ##
AC_CONFIG_FILES([Makefile])
AC_OUTPUT
