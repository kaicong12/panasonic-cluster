import csv
# all = []
# with open('tvd_image.csv') as csv_file:
#     csv_reader = csv.reader(csv_file, delimiter='\n')
#     for row in csv_reader:
#         row.append("1920")
#         row.append("1080")

# with open('tvd_image.csv','r') as csvinput:
#     with open('tvd_image_wdt_hgt.csv', 'w') as csvoutput:
#         writer = csv.writer(csvoutput)
#         for row in csv.reader(csvinput):
#             writer.writerow(row+['1920'])
#             writer.writerow(row+['1080'])

with open('tvd_image.csv','r') as csvinput:
    with open('tvd_image_wdt_hgt.csv', 'w') as csvoutput:
        writer = csv.writer(csvoutput, lineterminator='\n', delimiter=' ')
        reader = csv.reader(csvinput)

        all = []

        for row in reader:
            row.append("1920")
            row.append("1080")
            all.append(row)

        writer.writerows(all)