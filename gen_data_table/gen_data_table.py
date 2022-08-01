import prettytable
import csv
import os

id = 0

image_data = prettytable.PrettyTable()

image_data.border = False

image_data.field_names = ["data_id", "name", "qp_set", "dataset_name"]

image_data.align = "l"

with open('flir.csv') as csv_file:
    csv_reader = csv.reader(csv_file, delimiter='\n')
    for row in csv_reader:
        name = row[0]
        print(name)
        image_data.add_row([id, name, "QP0", "FLIR"])
        id += 1


with open('openImage.csv') as csv_file:
    csv_reader = csv.reader(csv_file, delimiter='\n')
    for row in csv_reader:
        name = row[0].split("/")[1]
        print(name)
        image_data.add_row([id, name, "QP1", "openImage"])
        id += 1

with open('tvd_image.csv') as csv_file:
    csv_reader = csv.reader(csv_file, delimiter='\n')
    for row in csv_reader:
        name = row[0]
        print(name)
        image_data.add_row([id, name, "QP2", "TVD_image"])
        id += 1

image_data.align = "l"



video_data = prettytable.PrettyTable()

video_data.border = False

video_data.field_names = ["data_id", "name", "qp_set", "intra_period", "frame_rate", "frames_num", "frame_skip", "dataset_name"]

TVD_video_names = ["TVD-01", "TVD-02", "TVD-03"]
SFU_video_names = ["Traffic_2560x1600_30_crop", "Kimono1_1920x1080_24", "ParkScene_1920x1080_24", "Cactus_1920x1080_50", "BasketballDrive_1920x1080_50", "BQTerrace_1920x1080_60", "BasketballDrill_832x480_50", "BQMall_832x480_60", "PartyScene_832x480_50", "RaceHorses_832x480_30", "BasketballPass_416x240_50", "BQSquare_416x240_60", "BlowingBubbles_416x240_50", "RaceHorses_416x240_30", "FourPeople_1280x720_60", "Johnny_1280x720_60", "KristenAndSara_1280x720_60"]

tvd_dict = { # (IntraPeriod, FrameRate, FramesToBeEncoded, FrameSkip, QP_set_id)
    "TVD-01"                       : (64, 50, 3000, 0, "QP3"),
    "TVD-02"                       : (64, 50, 636, 0, "QP4"),
    "TVD-03"                       : (64, 50, 2334, 0, "QP3"),
}

sfu_dict = { # (IntraPeriod, FrameRate, FramesToBeEncoded, FrameSkip, QP_set_id)
    "Traffic_2560x1600_30_crop"    : (32, 30, 33, 117, "QP5"),
    "Kimono1_1920x1080_24"         : (32, 24, 33, 207, "QP6"),
    "ParkScene_1920x1080_24"       : (32, 24, 33, 207, "QP6"),
    "Cactus_1920x1080_50"          : (64, 50, 97, 403, "QP6"),
    "BQTerrace_1920x1080_60"       : (64, 60, 129, 471, "QP6"),
    "BasketballDrive_1920x1080_50" : (64, 50, 97, 403, "QP6"),
    "BQMall_832x480_60"            : (64, 60, 129, 471, "QP7"),
    "BasketballDrill_832x480_50"   : (64, 50, 97, 403, "QP7"),
    "PartyScene_832x480_50"        : (64, 50, 97, 403, "QP7"),
    "RaceHorses_832x480_30"        : (32, 30, 65, 235, "QP7"),
    "BQSquare_416x240_60"          : (64, 60, 129, 471, "QP8"),
    "BasketballPass_416x240_50"    : (64, 50, 97, 403, "QP8"),
    "BlowingBubbles_416x240_50"    : (64, 50, 97, 403, "QP8"),
    "RaceHorses_416x240_30"        : (32, 30, 65, 235, "QP8"),
    "KristenAndSara_1280x720_60"   : (64, 60, 129, 471, "QP9"),
    "Johnny_1280x720_60"           : (64, 60, 129, 471, "QP9"),
    "FourPeople_1280x720_60"       : (64, 60, 129, 471, "QP9"),
}

for name in TVD_video_names:
    video_data.add_row([id, name, tvd_dict[name][4], tvd_dict[name][0], tvd_dict[name][1], tvd_dict[name][2], tvd_dict[name][3], "TVD_video"])
    id += 1


for name in SFU_video_names:
    video_data.add_row([id, name, sfu_dict[name][4], sfu_dict[name][0], sfu_dict[name][1], sfu_dict[name][2], sfu_dict[name][3], "SFU_HW"])
    id += 1
video_data.align = "l"
# print(type(image_data))
# print(video_data)
with open('image_data.txt', 'w') as f:
    f.write(str(image_data))

with open('video_data.txt', 'w') as f:
    f.write(str(video_data))