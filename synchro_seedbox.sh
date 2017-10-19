#!/bin/bash

set -x
OLDIFS=$IFS
source /etc/profile
vert="\\033[1;32m"
gris="\\033[0;39m"
rouge="\\033[1;31m"

# configuration : ftp / user / pass
servFTP=ns518626.dediseedbox.com
userFTP=tarantino22
passFTP=passwd
# configuration
repFTP=download
repLocal=/volume1/seedbox/
#on verifie si le script n'est pas déja lancé
pid_script=$(ps aux  | grep wget | grep -v grep | awk -F " " '{print $2}')

#variable mail
subject="Nouveau fichier téléchargé"

if [[ -n $pid_script ]]
then
        echo -e "`date` : Script déja en cours d'execution" >> /var/log/syncro_seedbox.log
        exit 0
fi
#recupération des noms de fichier sur le ftp
curl -L ftp://tarantino22:tenrasimak@ns518626.dediseedbox.com/download/ | awk '{printf $9; for(i=10;i<=NF;i++) printf OFS $i; printf ORS}' > fichier_ftp
IFS=$'\n'
for fichier in $(cat fichier_ftp)
do
                if [ -f /volume1/seedbox/$fichier ] || [ -d /volume1/seedbox/$fichier ]
                then
                        message="${rouge}`date` : pas de fichier à télécharger ${gris}"
                else

                        taille_fichier=`lftp ftp://$userFTP:$passFTP@$servFTP/$repFTP -e "du -s ./\"$fichier\"; exit" | awk '{print $1}'`
                        sleep 30
                        taille_fichier2=`lftp ftp://$userFTP:$passFTP@$servFTP/$repFTP/ -e "du -s ./\"$fichier\"; exit" | awk '{print $1}'`
                        if [[ $taille_fichier -ne $taille_fichier2 ]]
                        then
                                echo -e "`date` : Le fichier $fichier est toujours en cours de téléchargement sur la seedbox"
                                exit 0
                        fi

                        echo -e "`date` : téléchargement de $fichier" >> /mail/liste_seedbox
                        fichier_test_space=${fichier//[[:blank:]]/}
                        if [[ $fichier = $fichier_test_space ]]
                        then
                                wget -r -l 0 ftp://ns518626.dediseedbox.com/$repFTP/$fichier --ftp-user=$userFTP --ftp-password=$passFTP -nH  --cut-dirs=1 -P $repLocal
                                echo -e "${vert}`date` : $fichier téléchargé ${gris}" >> /var/log/synchro_seedbox.log
                        else
                                 fichier_test_space=`echo $fichier_test_space | tr -d [ | tr -d ] | tr -d \( | tr -d \)`
                                 lftp ftp://tarantino22:tenrasimak@ns518626.dediseedbox.com/download -e "mv \"$fichier\"  \"$fichier_test_space\"; exit"
                                 wget -r -l 0 ftp://ns518626.dediseedbox.com/$repFTP/$fichier_test_space --ftp-user=$userFTP --ftp-password=$passFTP -nH  --cut-dirs=1 -P $repLocal
                                 mv $repLocal/$fichier_test_space $repLocal/"$fichier"
                                 lftp ftp://tarantino22:tenrasimak@ns518626.dediseedbox.com/download -e "mv \"$fichier_test_space\" \"$fichier\"; exit"
                                 echo -e "${vert}`date` : $fichier téléchargé ${gris}" >> /var/log/synchro_seedbox.log
                        fi
                fi
done
IFS=$OLDIFS
#si pas de fichier à dl, on le marque dans les logs
[[ -n $message ]] && echo -e $message  >> /var/log/synchro_seedbox.log

#envoi du mail
[[ ! -f /mail/liste_seedbox ]] && exit 1

echo "`cat /mail/liste_seedbox`" | /opt/bin/nail -v -s "$subject" quentin.jegou@gmail.com
rm /mail/liste_seedbox
exit 0
