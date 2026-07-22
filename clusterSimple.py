import numpy as np
from sklearn.decomposition import PCA
from sklearn.mixture import GaussianMixture
from sklearn.preprocessing import StandardScaler
import pandas as pd

def clusterSimple(preprocessed_data, n_clusters = 20, n_repeats = 10, do_PCA = True):
    """
    Function to run KSMeans clustering on data with at least two features, optimising the number of clusters based on Bayesian Information Criterion.
    INPUTS:
        preprocessed_data - !!!(n_samples, n_features) shaped matrix; e.g. if you care about every timepoint, then it will be (n_syns,n_pnts) shape, OPPOSITE TO IGOR!!!
        n_clusters - (int) maximum acceptable number of clusters; lower number makes it faster, but might miss a potential optimal solution
        n_repeats - (int) number of randomized runs to obtain the best clustering
        do_PCA - (bool) option for transforming data into PCs prior to clustering
    OUTPUTS:
        labels - (n_samples) shaped array with the cluster number for each sample
    """

    # works faster, and I think better, with PCA
    if (do_PCA):
        standardized_data = StandardScaler().fit_transform(preprocessed_data)
        reduced_data = PCA(n_components=2).fit_transform(standardized_data)  
    else: 
        reduced_data = preprocessed_data

    # run kmeans for each possible number of clusters
    ks = range(1,n_clusters)
    KMeansSizes = [GaussianMixture(n_components=i, init_params='kmeans', n_init=n_repeats).fit(reduced_data) for i in ks]

    # get the information criterions
    #AIC = [kmeansi.aic(reduced_data) for kmeansi in KMeansSizes]
    BIC = [kmeansi.bic(reduced_data) for kmeansi in KMeansSizes]

    # choose and refit the best model based on BIC - I think it does a better job than AIC
    GMMKMeans = KMeansSizes[np.argmin(BIC)] 
    GMMKMeans.fit(reduced_data) 

    # get the output
    labels = GMMKMeans.predict(reduced_data) 

    return labels



# assuming execute command from Igor in the form:
# python script wave --tempFolder --filename
if __name__ == "__main__":
    import sys, os
    from platform import system
    from pig_helper_fxs import save_output
    tempFolder, waveFilename = "", ""
    for ei,arg in enumerate(sys.argv):
        if arg.startswith('--tempFolder'):
            tempFolder = str(arg.split('=')[1])
        if arg.startswith('--waveFilename'):
            waveFilename = str(arg.split('=')[1]) 
    if waveFilename and tempFolder:
        if system() == "Windows":
            wave_path = os.path.join(tempFolder[1:-1],waveFilename[1:-1])
        else:
            wave_path = os.path.join(tempFolder,waveFilename)
        wave = np.transpose(np.loadtxt(wave_path, delimiter=","))
        output = pd.DataFrame(clusterSimple(wave))
        save_output(output, wave_path, suffix="_uxu")
        os.remove(wave_path)
    else:
        print(f"tempFolder: {tempFolder}")
        print(f"waveName: {waveFilename}")
        print("?")
    

    
# 