# Installation

Installing the module into your place is simple, we will cover the different methods of installation down below.

## With Wally

SecureCast is available as a Wally package.
<br>Navigate to your projects `wally.toml` file and add the following dependancy
``` toml
secure-cast = "1axen/secure-cast"
```
After adding SecureCast to your dependencies you will need to install it by running
```
wally install
```

## With git

SecureCast can be directly cloned from [GitHub](https://github.com/1Axen/Secure-Cast)
```
git clone https://github.com/1Axen/Secure-Cast.git
```

!!! warning

    The master branch of the GitHub repository contains the latest development version and may not be stable.

## With GitHub releases

The latest stable version of the module can be downloaded from [https://github.com/1Axen/Secure-Cast/releases](https://github.com/1Axen/Secure-Cast/releases)<br>
After downloading the RBXM file insert it into ReplicatedStorage or any other shared container of your choice.

## Finishing up

SecureCast requires a `Map` and `Characters` folder placed within workspace to function correctly.<br>
All parts of the map must be a descendant of the `Map` folder. <br>
All player characters must be paranted to the `Characters` folder.

