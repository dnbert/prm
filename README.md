PRM
===

PRM allows you to quickly build package repositories, inspired by Jordan Sissels' FPM

Install
===
```
gem install prm
```
Example
===
```
prm --type deb --path pool --component dev,staging --release precise --arch amd64 --generate
```
Component, Release and Arch flags can have multiple values seperated by commas.
