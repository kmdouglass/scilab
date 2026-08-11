{ config, lib, pkgs, ... }:

{
    programs.bash.shellAliases = {
        # console
        ls = "ls -Fl --color";
        lsa = "ls -aFl --color";
        tl = "tree -L";

        # git
        gd = "git diff";
        gs = "git status";
        gau = "git add -u";
        gbd = "git branch -D";
        gcm = "git commit";
        gco = "git checkout";
        gds = "git diff --staged";
        glg = "git log --graph";
        gpf = "git push --force";
        gpl = "git pull";
        gpr = "git pull --rebase";
        gps = "git push";
        gri = "git rebase -i";
        gcma = "git commit --amend";
        gcob = "git checkout -b";
        gcmmsg = "git commit -m";
    };
}
