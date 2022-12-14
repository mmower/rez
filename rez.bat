@echo off

rem Run the rez compiler
rem escript is the directly-invokable executable on Windows,
rem   and will be in your PATH after installing Elixir.
rem %~dp0 is the directory of this batch script, which should
rem   be colocated with the built rez compiler.
rem %* passes along all arguments.
escript %~dp0rez %*
