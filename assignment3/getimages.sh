#!/bin/bash

# Student Unit: CSI6203
# Student Name: Yuhang Yang
# Student Number: 10513184

yh_created_dirs=() # used to record which directoreis are created by this script
yh_created_files=() # used to record which files are created by this script
yh_available_indexes=() # used to indicate which images are available
total_size=0 # used to calculate total size when downloading multiple images

# This function is used to check if user want to do something.
yh_function_confirm(){
    while true; do
        read -p " $1 [Y/N] " user_input
        if [ "${user_input}" == "Y" ] || [ "${user_input}" == "y" ]; then
            echo "true"
            break
        elif [ "${user_input}" == "N" ] || [ "${user_input}" == "n" ];then
            echo ""
            break
        fi
    done
}

# Firstly, check if the path exists, and create the directory if not exists
read -p "Please enter your path to store files: " yh_directory
echo "Your path is: ${yh_directory}"
if [ ! -d "$yh_directory" ];then
    echo "Path not exists, creating ..."
    mkdir "$yh_directory"
    yh_created_dirs+=("$yh_directory")
    echo "Path\"${yh_directory}\"  created."
else
    echo "Path \"${yh_directory}\" already exists, skipped."
fi
# An additional function using to make sure this function can be download images and delete them repeatly

#yh_assure_working_directory_exists(){
#    if [ ! -d "$yh_directory" ];then
#        mkdir "$yh_directory"
#    fi
#}
#yh_assure_working_directory_exists

# This function is used to download a single thumbnail, without user interactions.
yh_Download_image_core(){
    header_file=$(mktemp)
    index="$1"
    url="https://secure.ecu.edu.au/service-centres/MACSC/gallery/ml-2018-campus/DSC0${index}.jpg"
    echo -n "Calculating DSC0${index} size ..."
    curl --head --silent -q "$url" | grep "Content-Length" | tr -d "\r" | cut -d " " -f 2 > "${header_file}"
    size=$(cat "${header_file}")
    size=$(("${size}" / 1024))
    total_size=$(("$total_size" + "$size"))
    rm "$header_file"
    echo " Done. Size=${size} KB."
    echo -n "Downloading DSC0${index}, with the file name DSC0${index}.jpg, with a file size of ${size} KB ..."
    image_path="${yh_directory}/DSC0${index}.jpg"
    wget -q "${url}" -O "$image_path"
    yh_created_files+=("$image_path")
    echo " Thumbnail Download Completed."
}

# This function is used to download a single thumbnail, includes user interactions.
# Param 1: last for digits of thumbnail serial number.
yh_function_1_download_specific_image(){
    #yh_assure_working_directory_exists
    index="$1"
    image_path="${yh_directory}/DSC0${index}.jpg"
    if [ -f "$image_path" ];then
        if [ "$(yh_function_confirm "File \"${image_path}\" exists, remove?")" ];then
            rm "$image_path"
            echo "Old thumbnail file removed."
            yh_Download_image_core "$index"
        else
            echo 'Skipped.'
        fi
    else
        yh_Download_image_core "$index"
    fi
}

yh_function_2_download_images_in_range(){
    #yh_assure_working_directory_exists
    total_size=0
    start_range="$1"
    end_range="$2"
    echo "Downloading images in range: ${start_range}-${end_range}."
    for index in "${yh_available_indexes[@]}";do
        if [ "$start_range" -le "$index" ] && [ "$end_range" -ge "$index" ];then
            yh_function_1_download_specific_image "${index}"
        fi
    done
    echo "Downloading images in range: ${start_range}-${end_range}. Download completed. Total size: ${total_size} KB."
}

yh_function_3_download_specific_number_of_images(){
    #yh_assure_working_directory_exists
    total_size=0
    echo "Downloading specific number of images: $1."
    indexes_file=$(mktemp)
    filtered_file=$(mktemp)
    for index in "${yh_available_indexes[@]}";do
        echo "${index}" >> "${indexes_file}"
    done

    shuf -n "$1" "${indexes_file}" > "${filtered_file}"
    filtered_indexes=()
    while read -r line; do
        filtered_indexes+=("${line}")
    done < "$filtered_file"
    rm "${indexes_file}"
    rm "${filtered_file}"
    for index in "${filtered_indexes[@]}";do
        yh_function_1_download_specific_image "$index"
    done
    echo "Downloading specific number of images: $1. Download completed. Total size: ${total_size} KB."
}

yh_function_4_download_all_files(){
    #yh_assure_working_directory_exists
    total_size=0
    echo -n 'Clean up all files created by this script ...'
    for index in "${yh_available_indexes[@]}";do
        yh_function_1_download_specific_image "$index"
    done
    echo "Downloading all thumbnails. Download completed. Total size: ${total_size} KB. "
}

yh_function_5_clean_up_all_files(){
    echo -n 'Clean up all files created by this script ...'
    for file_path in "${yh_created_files[@]}"; do
      rm "$file_path"
    done
    for dir_path in "${yh_created_dirs[@]}"; do
      rm -r "$dir_path"
    done
    #yh_created_files=()
    #yh_created_dirs=()
    echo ' Done.'
}

# Download index.html_file from site, and analyze which files are available
echo -n "Thumbnail indexes downloading ..."
html_file="$(mktemp)"
indexes_file="$(mktemp)"
wget "https://www.ecu.edu.au/service-centres/MACSC/gallery/gallery.php?folder=ml-2018-campus" -qO "${html_file}"
grep "img src=" "${html_file}" |\
    awk '{print $2}' |\
    cut -d "\"" -f 2 |\
    cut -d "." -f 4 |\
    cut -d "C" -f 4 > "$indexes_file"

while read -r line;do
    yh_available_indexes+=("${line:1}")
done < "$indexes_file"
rm "$html_file"
rm "$indexes_file"
echo " Done."

while true;do
    echo -e "1) Download a specific thumbnail;\n2) Download images in a range;\n3) Download a specified number of images;\n4) Download all thumbnails;\n5) Clean up all files;\n6) Exit program."
    read -p "Choice:" choice
    case $choice in
    1)
        echo 'Your choice: Download a sepecific thumbnail.'
        while true;do
            read -p 'Please enter last four digits of thumbnail serial number: ' index
            if [[ "${#index}" == 4 ]];then
                break
            else
                echo "Please enter last **FOUR** digits."
            fi
        done
        if [[ "${yh_available_indexes[*]}" == *"$index"* ]]; then
            yh_function_1_download_specific_image "$index"
            echo 'Done, back to main menu.'
        else
            echo 'Thnmbnail \"${index}\" does not exists, back to main menu.'
        fi
        ;;
    2)
        echo 'Your choice: Download images in a range.'
        read -p 'Please enter last four digits of start thumbnail serial number: ' start_index
        read -p 'Please enter last four digits of end thumbnail serial number: ' end_index
        yh_function_2_download_images_in_range "$start_index" "$end_index"
        echo 'Done, back to main menu'
        ;;
    3)
        echo 'Your choice: Download a specified number of images.'
        read -p 'Please enter image count: ' count
        yh_function_3_download_specific_number_of_images "$count"
        echo 'Done, back to main menu'
        ;;
    4)
        echo 'Your choice: Download all thumbnails.'
        yh_function_4_download_all_files
        echo 'Done, back to main menu'
        ;;
    5)
        echo 'Your choice: Clean up all diles.'
        yh_function_5_clean_up_all_files
        echo 'Done, back to main menu'
        ;;
    6)
        echo 'Your choice: Exit program.'
        exit 0
        ;;
    *) 
        echo 'Wrong choice, please enter again.'
    esac
done